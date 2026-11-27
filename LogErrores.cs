using System;
using System.IO;

namespace DPieCenter
{
    public class LogErrores : IDisposable
    {
        private bool disposed = false;
        public enum TipoError
        {
            BaseDeDatos = 1,
            Interface = 2,
            Archivos = 7,
            Debug = 99
        }

        public void SaveLogError(TipoError NoError, long id_usuario, string funcion, string UsuarioID, string datos)
        {

            using (SqlProcess objLog = new SqlProcess())
            {
                objLog.mtdSys_LogErrores(id_usuario, funcion, UsuarioID, datos);
            }

            string NombreArchivo = "";
            if (NoError == TipoError.BaseDeDatos)
            {
                NombreArchivo = @"C:\temp\" + "BaseDeDatos_" + DateTime.Now.ToString("yyyy_MM_dd") + ".txt";
                string lineas = DateTime.Now.ToString("yyyy_MM_dd HH:mm:ss") + " ==== " + datos + "\n\r";
                using (StreamWriter sw = new StreamWriter(NombreArchivo, true))
                {
                    sw.WriteLine("-------------------" + funcion + " --" + UsuarioID + " --------------");
                    sw.WriteLine(lineas);
                }

            }
            else if (NoError == TipoError.Debug)
            {
                NombreArchivo = @"C:\temp\" + "Debug" + DateTime.Now.ToString("yyyy_MM_dd") + ".txt";
                string lineas = DateTime.Now.ToString("yyyy_MM_dd HH:mm:ss") + " ==== " + datos + "\n\r";
                using (StreamWriter sw = new StreamWriter(NombreArchivo, true))
                {
                    sw.WriteLine("--------------------------------------");
                    sw.WriteLine(lineas);
                }

            }
            else if (NoError == TipoError.Archivos)
            {
                NombreArchivo = @"C:\temp\" + "Archivos" + DateTime.Now.ToString("yyyy_MM_dd") + ".txt";
                string lineas = DateTime.Now.ToString("yyyy_MM_dd HH:mm:ss") + " ==== " + datos + "\n\r";
                using (StreamWriter sw = new StreamWriter(NombreArchivo, true))
                {
                    sw.WriteLine("--------------------------------------");
                    sw.WriteLine(lineas);
                }

            }

        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!this.disposed)
            {
                if (disposing)
                {
                    // Dispose managed resources.
                }

                disposed = true;

            }
        }
    }
}