/* =====================================================================
   DPieCenter - Pago combinado: varias formas de pago en un mismo DTE (Facturacion/frm_OpenFactura.aspx)

   FAC_DTE_PAGOS: una fila por forma de pago del documento con el monto APLICADO al total
                  (en efectivo, lo recibido menos el cambio). La suma de las filas = TotalPagar.
                  FAC_DTE_DOCUMENTOS.FormaPago sigue guardando la forma principal (la de mayor monto).
   FAC_VW_DTE_PAGOS: pagos de cada documento; los emitidos antes del pago combinado (sin filas en
                  FAC_DTE_PAGOS) salen con su única forma de pago y el total, así los reportes no cambian.
   FAC_FN_EfectivoCajero: efectivo cobrado por un cajero en un día (DTE vigentes) para el arqueo.
   FAC_FN_FormasPagoTexto: "Billetes y monedas" o "Tarjeta Crédito $15.00 + Billetes y monedas $8.90".
   FAC_SP_DTE_GUARDARPAGO: guarda una línea de pago (dentro de la transacción de la emisión).
   Requiere FAC_DTE_Estructura.sql. Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.FAC_DTE_PAGOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FAC_DTE_PAGOS (
        Id_Pago     bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FAC_DTE_PAGOS PRIMARY KEY,
        Id_Dte_FK   bigint        NOT NULL CONSTRAINT FK_FAC_DTE_PAGOS_Dte REFERENCES dbo.FAC_DTE_DOCUMENTOS (Id_Dte),
        FormaPago   char(2)       NOT NULL,          -- CAT-017
        Monto       decimal(12,2) NOT NULL,          -- aplicado al total (efectivo: recibido - cambio)
        Recibido    decimal(12,2) NULL,              -- solo efectivo: lo que entregó el cliente
        Referencia  varchar(50)   NULL,
        UsuarioCrea varchar(20)   NOT NULL,
        FechaCrea   datetime      NOT NULL CONSTRAINT DF_FAC_DTE_PAGOS_Fecha DEFAULT (GETDATE())
    );
    CREATE INDEX IX_FAC_DTE_PAGOS_Dte ON dbo.FAC_DTE_PAGOS (Id_Dte_FK) INCLUDE (FormaPago, Monto);
END
GO

CREATE OR ALTER VIEW dbo.FAC_VW_DTE_PAGOS
AS
    select p.Id_Dte_FK as Id_Dte, p.FormaPago, p.Monto, p.Referencia
    from dbo.FAC_DTE_PAGOS as p
    union all
    -- documentos emitidos con una sola forma de pago (antes del pago combinado)
    select d.Id_Dte, d.FormaPago, ISNULL(d.TotalPagar, 0), d.ReferenciaPago
    from dbo.FAC_DTE_DOCUMENTOS as d
    where not exists (select 1 from dbo.FAC_DTE_PAGOS as x where x.Id_Dte_FK = d.Id_Dte);
GO

CREATE OR ALTER FUNCTION dbo.FAC_FN_EfectivoCajero (@cajero varchar(20), @fecha date)
RETURNS decimal(12,2)
AS
BEGIN
    RETURN ISNULL((select SUM(p.Monto)
                   from dbo.FAC_DTE_DOCUMENTOS as d
                       inner join dbo.FAC_VW_DTE_PAGOS as p on p.Id_Dte = d.Id_Dte and p.FormaPago = '01'
                   where d.UsuarioCrea = @cajero and d.FechaEmision = @fecha and d.Estado <> 'A'), 0);
END
GO

CREATE OR ALTER FUNCTION dbo.FAC_FN_FormasPagoTexto (@dte bigint)
RETURNS varchar(400)
AS
BEGIN
    declare @n int = (select COUNT(*) from dbo.FAC_VW_DTE_PAGOS where Id_Dte = @dte)
    if @n <= 1
        RETURN (select top 1 ISNULL(fp.Descripcion, p.FormaPago)
                from dbo.FAC_VW_DTE_PAGOS as p left join dbo.CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
                where p.Id_Dte = @dte);
    RETURN STUFF((select ' + ' + ISNULL(fp.Descripcion, p.FormaPago) + ' $' + CONVERT(varchar(20), CAST(p.Monto as money), 1)
                  from dbo.FAC_VW_DTE_PAGOS as p left join dbo.CAT_FORMASPAGO as fp on fp.Codigo = p.FormaPago
                  where p.Id_Dte = @dte
                  order by p.Monto desc, p.FormaPago
                  for xml path(''), type).value('.', 'varchar(400)'), 1, 3, '');
END
GO

CREATE OR ALTER PROCEDURE dbo.FAC_SP_DTE_GUARDARPAGO
     @dte        bigint
    ,@formaPago  char(2)
    ,@monto      decimal(12,2)
    ,@recibido   decimal(12,2) = NULL
    ,@referencia varchar(50) = NULL
    ,@usuario    varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    if not exists (select 1 from dbo.CAT_FORMASPAGO where Codigo = @formaPago)
        THROW 50460, 'La forma de pago no es válida.', 1;
    if @monto <= 0
        THROW 50461, 'Cada forma de pago debe tener un monto mayor a cero.', 1;
    insert into dbo.FAC_DTE_PAGOS (Id_Dte_FK, FormaPago, Monto, Recibido, Referencia, UsuarioCrea)
    values (@dte, @formaPago, @monto, @recibido, NULLIF(LTRIM(RTRIM(@referencia)), ''), @usuario);
END
GO
