using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Caching;

namespace DPieCenter
{
    /// <summary>
    /// Bloqueo temporal tras varios intentos fallidos de inicio de sesión.
    /// Se cuenta por usuario desde cada IP (así quien adivine claves desde fuera no bloquea al usuario real en su equipo),
    /// por usuario en total (límite mayor, contra ataques desde muchas IP) y por IP (límite mayor, contra probar muchos usuarios).
    /// Se guarda en memoria del servidor: se reinicia si se recicla la aplicación (no requiere tablas nuevas).
    /// Un administrador puede ver los usuarios con fallos y desbloquearlos en Opciones > Usuarios.
    /// </summary>
    public static class LoginIntentos
    {
        public const int MaxIntentos = 5;                    // por usuario desde una misma IP
        private const int MaxIntentosUsuarioTotal = 30;      // por usuario desde cualquier IP
        private const int MaxIntentosIp = 20;                // por IP, con cualquier usuario
        public static readonly TimeSpan Ventana = TimeSpan.FromMinutes(15);

        private static readonly MemoryCache Cache = new MemoryCache("DPieCenter.LoginIntentos");

        private class Registro
        {
            public int Fallos;
            public DateTime Desde;
            public DateTime? BloqueadoHasta;
            public DateTime Ultimo;
            public string Ip;              // última IP desde la que falló (para desbloquearla junto con el usuario)
        }

        /// <summary>Estado de un usuario con intentos fallidos recientes.</summary>
        public class EstadoBloqueo
        {
            public string Usuario { get; set; }
            public int Fallos { get; set; }
            public bool Bloqueado { get; set; }
            public int Minutos { get; set; }       // minutos que faltan para el desbloqueo automático
            public string UltimoIntento { get; set; }
        }

        private const string PrefijoUsuarioIp = "ui:";
        private const string PrefijoUsuarioTotal = "ut:";
        private static string Nombre(string usuario) { return (usuario ?? "").Trim().ToLowerInvariant().Replace("|", "_"); }
        private static string ClaveUsuarioIp(string usuario, string ip) { return PrefijoUsuarioIp + Nombre(usuario) + "|" + (ip ?? ""); }
        private static string ClaveUsuarioTotal(string usuario) { return PrefijoUsuarioTotal + Nombre(usuario); }
        private static string ClaveIp(string ip) { return "ip:" + (ip ?? ""); }

        /// <summary>Minutos que faltan para desbloquear (0 si no está bloqueado).</summary>
        public static int MinutosBloqueo(string usuario, string ip)
        {
            return Math.Max(Restante(ClaveUsuarioIp(usuario, ip)), Math.Max(Restante(ClaveUsuarioTotal(usuario)), Restante(ClaveIp(ip))));
        }

        private static int Restante(string clave)
        {
            var r = Cache.Get(clave) as Registro;
            if (r == null || !r.BloqueadoHasta.HasValue) return 0;
            var falta = r.BloqueadoHasta.Value - DateTime.Now;
            return falta <= TimeSpan.Zero ? 0 : (int)Math.Ceiling(falta.TotalMinutes);
        }

        /// <summary>Registra un fallo y devuelve los intentos que quedan antes del bloqueo.</summary>
        public static int RegistrarFallo(string usuario, string ip)
        {
            int quedan = Fallo(ClaveUsuarioIp(usuario, ip), MaxIntentos, ip);
            Fallo(ClaveUsuarioTotal(usuario), MaxIntentosUsuarioTotal, ip);
            Fallo(ClaveIp(ip), MaxIntentosIp, ip);
            return quedan;
        }

        private static int Fallo(string clave, int maximo, string ip)
        {
            lock (Cache)
            {
                var ahora = DateTime.Now;
                var r = Cache.Get(clave) as Registro;
                if (r == null || ahora - r.Desde > Ventana) r = new Registro { Desde = ahora };
                r.Fallos++;
                r.Ultimo = ahora;
                r.Ip = ip;
                if (r.Fallos >= maximo) r.BloqueadoHasta = ahora.Add(Ventana);
                Cache.Set(clave, r, ahora.Add(Ventana).AddMinutes(1));
                return Math.Max(0, maximo - r.Fallos);
            }
        }

        // También se limpia la IP: si la clínica sale a internet por una sola IP, los fallos de todos se sumarían
        public static void Limpiar(string usuario, string ip)
        {
            Cache.Remove(ClaveUsuarioIp(usuario, ip));
            Cache.Remove(ClaveUsuarioTotal(usuario));
            Cache.Remove(ClaveIp(ip));
        }

        /// <summary>
        /// Quita el bloqueo y los fallos del usuario (desde cualquier IP) y de las IP desde las que falló (administrador o recuperación de clave).
        /// Devuelve true si tenía fallos registrados.
        /// </summary>
        public static bool Desbloquear(string usuario)
        {
            if (string.IsNullOrWhiteSpace(usuario)) return false;
            lock (Cache)
            {
                bool tenia = false;
                string prefijo = PrefijoUsuarioIp + Nombre(usuario) + "|";
                foreach (var clave in Cache.Select(x => x.Key).Where(k => k.StartsWith(prefijo, StringComparison.Ordinal)).ToList())
                {
                    var r = Cache.Remove(clave) as Registro;
                    if (r != null) { tenia = true; if (!string.IsNullOrEmpty(r.Ip)) Cache.Remove(ClaveIp(r.Ip)); }
                }
                if (Cache.Remove(ClaveUsuarioTotal(usuario)) != null) tenia = true;
                return tenia;
            }
        }

        /// <summary>Usuarios con intentos fallidos en los últimos 15 minutos (bloqueados o no).</summary>
        public static List<EstadoBloqueo> Usuarios()
        {
            var ahora = DateTime.Now;
            var items = Cache.Where(x => x.Value is Registro).Select(x => new { x.Key, R = (Registro)x.Value }).ToList();

            return items.Where(x => x.Key.StartsWith(PrefijoUsuarioTotal, StringComparison.Ordinal))
                .Select(x =>
                {
                    string usuario = x.Key.Substring(PrefijoUsuarioTotal.Length);
                    string prefijo = PrefijoUsuarioIp + usuario + "|";
                    var porIp = items.Where(i => i.Key.StartsWith(prefijo, StringComparison.Ordinal)).Select(i => i.R).ToList();
                    var todos = porIp.Concat(new[] { x.R }).ToList();
                    int min = todos.Where(r => r.BloqueadoHasta.HasValue && r.BloqueadoHasta > ahora)
                                   .Select(r => (int)Math.Ceiling((r.BloqueadoHasta.Value - ahora).TotalMinutes)).DefaultIfEmpty(0).Max();
                    return new { Usuario = usuario, Fallos = x.R.Fallos, Min = min, Ultimo = x.R.Ultimo, Reciente = ahora - x.R.Desde <= Ventana };
                })
                .Where(x => x.Reciente || x.Min > 0)
                .Select(x => new EstadoBloqueo
                {
                    Usuario = x.Usuario, Fallos = x.Fallos, Bloqueado = x.Min > 0, Minutos = x.Min, UltimoIntento = Formato.Hora(x.Ultimo)
                })
                .OrderByDescending(x => x.Bloqueado).ThenBy(x => x.Usuario)
                .ToList();
        }
    }
}
