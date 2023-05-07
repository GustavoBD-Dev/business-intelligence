SELECT
    'FS' AS empresa,
    'Abril' AS periodo,
    COALESCE(
        exigibles.credito,
        (   SELECT idsucaux || '-' || idproducto || '-' || idauxiliar
              FROM auxiliares_ref ar
             WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                   (COALESCE(abonos.cuenta, exigibles.cuenta))
             LIMIT 1 ), 
        (   SELECT idsucaux || '-' || idproducto || '-' || idauxiliar
              FROM auxiliares_ref_bk ar
             WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                   ( COALESCE(abonos.cuenta, exigibles.cuenta) )
             LIMIT 1 )
    ) AS credito,
    COALESCE(
        exigibles.producto,
        (   SELECT idproducto
              FROM auxiliares_ref ar
             WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                   ( COALESCE(abonos.cuenta, exigibles.cuenta) )
             LIMIT 1 ), 
        (   SELECT idproducto
              FROM auxiliares_ref_bk ar
             WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                   ( COALESCE(abonos.cuenta, exigibles.cuenta) )
             LIMIT 1 )
    ) AS producto,
    COALESCE(
        exigibles.saldo,
        (  SELECT saldo
             FROM deudores d
                  LEFT JOIN auxiliares_ref ar USING(idsucaux, idproducto, idauxiliar)
            WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                  ( COALESCE(abonos.cuenta, exigibles.cuenta) )
            LIMIT 1
        ), (
            SELECT saldo
              FROM deudores d
                   LEFT JOIN auxiliares_ref_bk ar USING(idsucaux, idproducto, idauxiliar)
             WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                   ( COALESCE(abonos.cuenta, exigibles.cuenta) )
             LIMIT 1
        )
    ) AS capital,
    COALESCE(
        exigibles.tasaio,
        (   SELECT tasaio
              FROM deudores d
                   LEFT JOIN auxiliares_ref ar USING(idsucaux, idproducto, idauxiliar)
             WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                   ( COALESCE(abonos.cuenta, exigibles.cuenta) )
             LIMIT 1 ), 
        (   SELECT tasaio
              FROM deudores d
                   LEFT JOIN auxiliares_ref_bk ar USING(idsucaux, idproducto, idauxiliar)
             WHERE ( idsucauxref || '-' || idproductoref || '-' || idauxiliarref ) = 
                   ( COALESCE(abonos.cuenta, exigibles.cuenta) )
             LIMIT 1
        )
    ) AS tasa,
    COALESCE(exigibles.cuenta, abonos.cuenta) AS cuenta,
    COALESCE(exigibles.cliente, abonos.cliente) AS cliente,
    COALESCE(exigibles.nombre, abonos.nombre) AS nombre,
    COALESCE(exigibles.mensualidad, 0) AS mensualidad,
    COALESCE(abonos.abonos, 0) AS abonos
FROM
    (SELECT saldo,
            --(SELECT saldo FROM of_deudor(d.idsucaux, d.idproducto, d.idauxiliar, '31-03-2023')) AS saldo, --saldo, 
            tasaio,
            (SELECT idsucauxref || '-' || idproductoref || '-' || idauxiliarref
               FROM of_auxiliar_ref(d.idsucaux, d.idproducto, d.idauxiliar, 2001)
            ) AS cuenta,
            d.idsucaux || '-' || d.idproducto || '-' || d.idauxiliar AS credito,
            d.idproducto AS producto,
            d.idsucursal || '-' || d.idrol || '-' || d.idasociado AS cliente,
            of_nombre_asociado(idsucursal, idrol, idasociado) AS nombre,
            (SELECT
                ROUND(
                    of_si(
                        of_iva_general(
                            d.idsucaux,
                            d.idproducto,
                            d.idauxiliar,
                            1,
                            NOW() :: DATE
                        ),
                        (
                            round(abono + io, 2) + round((round(io, 2) * round(0.16, 2)), 2)
                        ),
                        abono + io
                    ) + (
                        COALESCE(
                            (
                                ROUND(
                                    CAST(p.ca -> '1' ->> 'monto' AS DECIMAL(8, 2)),
                                    2
                                ) + (
                                    ROUND(
                                        (
                                            CAST(p.ca -> '2' ->> 'monto' AS DECIMAL(8, 2)) * 1.16
                                        ),
                                        2
                                    )
                                ) + ROUND(
                                    (
                                        CAST(p.ca -> '3' ->> 'monto' AS DECIMAL(8, 2)) * 1.16
                                    ),
                                    2
                                ) + CAST(p.ca -> '5' ->> 'monto' AS DECIMAL(8, 2)) + ROUND(COALESCE(pe.io_incr, 0), 2)
                            ),
                            0
                        )
                    ),
                    2
                )
                FROM
                    planpago p
                    LEFT JOIN ppv.planpago_escalonado pe ON d.kauxiliar = pe.kauxiliar
                    AND p.idpago = pe.idpago
                WHERE
                    (idsucaux, idproducto, idauxiliar) = (d.idsucaux, d.idproducto, d.idauxiliar)
                    AND vence BETWEEN '01-04-2023'
                    AND '30-04-2023'
                LIMIT
                    1
            ) AS mensualidad
        FROM
            deudores d
        WHERE
            estatus = 3
            AND idproducto IN (
                SELECT
                    idproducto
                FROM
                    of_dep_productos('PRE')
            )
    ) AS exigibles 
    FULL JOIN 
    (
        SELECT
            idsucaux || '-' || idproducto || '-' || idauxiliar AS cuenta,
            idsucursal || '-' || idrol || '-' || idasociado AS cliente,
            of_nombre_asociado(idsucursal, idrol, idasociado) AS nombre,
            sum(abono) AS abonos
        FROM
            detalle_auxiliar da
            LEFT JOIN acreedores a USING(idsucaux, idproducto, idauxiliar)
        WHERE
            fecha BETWEEN '01-04-2023'
            AND '30-04-2023'
            AND tipopol = 1
            AND idproducto = 2001
        GROUP BY
            1,
            2,
            3
    ) AS abonos ON exigibles.cuenta = abonos.cuenta;