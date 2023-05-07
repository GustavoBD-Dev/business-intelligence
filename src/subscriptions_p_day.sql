SELECT da.fecha, 
       da.idsucaux ||'-'|| da.idproducto ||'-'|| da.idauxiliar AS cuenta,
       a.idsucursal ||'-'|| a.idrol ||'-'|| a.idasociado AS cliente,
       of_nombre_asociado(a.idsucursal,a.idrol,a.idasociado) AS nombre,
       (SELECT arb.idsucaux||'-'||arb.idproducto||'-'||arb.idauxiliar
          FROM auxiliares_ref arb 
               LEFT JOIN deudores d USING(idsucaux,idproducto,idauxiliar)
         WHERE (arb.idsucauxref,arb.idproductoref,arb.idauxiliarref)=(da.idsucaux,da.idproducto,da.idauxiliar)
               --AND d.estatus = 3 -- If the active filter does not show the credits that were settled with the last payment 
               ORDER BY d.fechaape DESC
               LIMIT 1
       ) AS credito,
       (SELECT arb.idproducto
          FROM auxiliares_ref arb 
               LEFT JOIN deudores d USING(idsucaux,idproducto,idauxiliar)
         WHERE (arb.idsucauxref,arb.idproductoref,arb.idauxiliarref)=(da.idsucaux,da.idproducto,da.idauxiliar)
               --AND d.estatus = 3   -- If the active filter does not show the credits that were settled with the last payment 
               ORDER BY d.fechaape DESC
               LIMIT 1
       ) AS idproducto,
       '__________' AS empresa,
       CASE
            WHEN LOWER(p.concepto) LIKE '%recaudo%' THEN 'RECAUDO'
            WHEN LOWER(p.concepto) LIKE '%bancario%' THEN 'ABONOS'
            ELSE 'ABONOS'
       END AS concepto,
       sum(abono) AS abono
  FROM detalle_auxiliar da 
       LEFT JOIN polizas p USING(idsucpol, tipopol, idpoliza, periodo) -- filter by concept
       LEFT JOIN acreedores a USING(idsucaux, idproducto, idauxiliar)  -- to get customer data
 WHERE da.idproducto = 2001  .-- type of product
       AND da.fecha  >= '01-03-2023' -- date filter
       AND da.abono != 0  -- only subscriptions
       AND tipopol = 1    -- filter by type of policies (1)
       GROUP BY 1,2,3,4,5,6,7,8
       ORDER BY empresa;