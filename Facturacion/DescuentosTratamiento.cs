using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace DPieCenter.Facturacion
{
    /// <summary>
    /// Descuento en % de cada tratamiento (CAT_TRATAMIENTOS.Descuento, Catálogos › Tratamientos).
    /// Se toma el vigente del catálogo mientras la factura no se cobra; al emitir el DTE queda en valores
    /// (montoDescu de la línea y totalDescu) y ya no cambia. Los tratamientos sin descuento no muestran nada.
    /// </summary>
    public static class DescuentosTratamiento
    {
        /// <summary>Id del tratamiento → % de descuento (solo los que tienen descuento).</summary>
        public static Dictionary<long, decimal> Vigentes()
        {
            var d = new Dictionary<long, decimal>();
            using (var cn = new SqlConnection(DteRepository.Cn))
            using (var cmd = new SqlCommand("select Id_Tratamientos, Descuento from dbo.CAT_TRATAMIENTOS where Descuento > 0", cn))
            {
                cn.Open();
                using (var rd = cmd.ExecuteReader())
                    while (rd.Read()) d[Convert.ToInt64(rd[0])] = Convert.ToDecimal(rd[1]);
            }
            return d;
        }

        public static decimal Porcentaje(Dictionary<long, decimal> vigentes, long idTratamiento)
        {
            decimal p;
            return vigentes != null && vigentes.TryGetValue(idTratamiento, out p) ? p : 0m;
        }

        /// <summary>Monto del descuento sobre un valor (redondeado a 2 decimales).</summary>
        public static decimal Monto(decimal valor, decimal porcentaje)
        {
            return porcentaje > 0 ? Math.Round(valor * porcentaje / 100m, 2, MidpointRounding.AwayFromZero) : 0m;
        }
    }
}
