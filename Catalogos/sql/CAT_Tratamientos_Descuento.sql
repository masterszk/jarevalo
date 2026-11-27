/* =====================================================================
   DPieCenter - Descuento en % por tratamiento (Catálogos › Tratamientos)

   CAT_TRATAMIENTOS.Descuento: 0 = sin descuento. Se aplica al cobrar (Facturacion/DescuentosTratamiento.cs):
   en la factura va en valores (montoDescu de la línea y totalDescu) y las pantallas de citas, procedimientos
   y caja muestran el precio con descuento. Debe ejecutarse antes que los SP que leen la columna
   (EXP_Agenda, EXP_Procedimientos_Atencion, CAJ_Caja_Anulaciones, CAT_Catalogos).
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.CAT_TRATAMIENTOS', 'Descuento') IS NULL
	ALTER TABLE dbo.CAT_TRATAMIENTOS ADD Descuento decimal(5,2) NOT NULL CONSTRAINT DF_CAT_TRATAMIENTOS_Descuento DEFAULT (0);
GO
