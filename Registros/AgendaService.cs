using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

namespace DPieCenter.Registros
{
    public static class AgendaService
    {
        public const int TipoExpressId = 2;   // Id del tipo de cita "Express" (según EXP_SP_ListaTiposCitas)
        public const int PasoMin = 60;   // la grilla va de 60 en 60 minutos (08:00, 09:00 ... 17:00)

        // Atención todos los días de la semana: 8:00 a 18:00 (última cita a las 17:00). Las citas Express también cierran a las 18:00.
        public static void Horario(DayOfWeek dia, bool express, out TimeSpan apertura, out TimeSpan cierre)
        {
            apertura = new TimeSpan(8, 0, 0);
            cierre = new TimeSpan(18, 0, 0);
        }

        // Redondea la duración hacia arriba a bloques de 60 min (mínimo 1 bloque)
        public static int Redondear(int minutos)
        {
            if (minutos < PasoMin) return PasoMin;
            return (int)Math.Ceiling(minutos / (double)PasoMin) * PasoMin;
        }

        /// <summary>Cita Express en la hora en curso (el bloque de 60 min que ya empezó): se agenda aunque el profesional tenga otra cita.</summary>
        public static bool EsHoraEnCursoExpress(bool express, DateTime inicio, DateTime ahora)
        {
            return express && inicio <= ahora && ahora < inicio.AddMinutes(PasoMin);
        }

        /// <summary>El bloque de la hora en curso tenía una cita que ya se cobró en caja: esa hora queda libre para agendar.</summary>
        public static bool HoraEnCursoLiberada(List<RangoOcupado> cobradas, DateTime inicio, DateTime ahora)
        {
            var fin = inicio.AddMinutes(PasoMin);
            return inicio <= ahora && ahora < fin && cobradas.Any(o => inicio < o.Fin && fin > o.Inicio);
        }

        public static DateTime LunesDe(DateTime fecha)
        {
            int diff = ((int)fecha.DayOfWeek + 6) % 7;
            return fecha.Date.AddDays(-diff);
        }

        public static SemanaDto ObtenerSemana(DateTime fechaRef, int profesionalId, int duracionMin, bool express)
        {
            duracionMin = Redondear(duracionMin);
            var lunes = LunesDe(fechaRef);
            var ocupados = CitasRepository.ObtenerOcupados(profesionalId, lunes, lunes.AddDays(7));
            var cobradas = CitasRepository.ObtenerOcupados(profesionalId, lunes, lunes.AddDays(7), true);
            var ahora = DateTime.Now;

            var semana = new SemanaDto { Lunes = lunes.ToString("yyyy-MM-dd"), DuracionMin = duracionMin };
            for (int i = 0; i < 7; i++)
            {
                var fecha = lunes.AddDays(i);
                TimeSpan apertura, cierre;
                Horario(fecha.DayOfWeek, express, out apertura, out cierre);

                var dia = new DiaDto { Fecha = fecha.ToString("yyyy-MM-dd") };
                for (var t = apertura; t + TimeSpan.FromMinutes(PasoMin) <= cierre; t += TimeSpan.FromMinutes(PasoMin))
                {
                    var ini = fecha + t;
                    var fin = ini.AddMinutes(duracionMin);
                    bool cabe = (t + TimeSpan.FromMinutes(duracionMin)) <= cierre;
                    // Express: también se puede tomar la hora en curso (el bloque que ya empezó pero no ha terminado),
                    // y esa hora queda disponible aunque el profesional ya tenga otra cita en ella.
                    // Hora en curso liberada porque la cita que la ocupaba ya se cobró en caja: disponible para cualquier tipo
                    bool liberada = HoraEnCursoLiberada(cobradas, ini, ahora);
                    var limite = express || liberada ? ini.AddMinutes(PasoMin) : ini;
                    bool libre = cabe && limite > ahora
                        && (EsHoraEnCursoExpress(express, ini, ahora) || !ocupados.Any(o => ini < o.Fin && fin > o.Inicio));
                    dia.Slots.Add(new SlotDto { Hora = t.ToString(@"hh\:mm"), Disponible = libre });
                }
                semana.Dias.Add(dia);
            }
            return semana;
        }

        // Usuario de la sesión cuando el WebMethod la tiene habilitada (EnableSession); si no, el que envía
        // el navegador ($('#idUser').val()). Antes se leía Session["dpsesion"] como texto y devolvía "System.Collections.ArrayList".
        public static string UsuarioActual(string user = null)
        {
            var ctx = System.Web.HttpContext.Current;
            string u = "admin";
            if (Sesion.Activa) u = Sesion.Usuario;
            else if (!string.IsNullOrWhiteSpace(user)) u = user.Trim();
            else if (ctx != null && ctx.User != null && ctx.User.Identity.IsAuthenticated) u = ctx.User.Identity.Name;
            return u.Length > 20 ? u.Substring(0, 20) : u;
        }

        public static List<TipoCitaDto> ObtenerTiposCita(string user)
        {
            return CitasRepository.ObtenerTiposCita(UsuarioActual(user));
        }

        // ===== Agenda tipo calendario =====
        // Evita que dos citas del mismo profesional empiecen dentro de la misma ventana.
        // Ponga en false si su SP EXP_SP_CitaUpdate ya valida choques o si permite sobreagendamiento.
        private const bool ValidarChoqueProfesional = true;

        public static CatalogosDto ObtenerCatalogos()
        {
            return new CatalogosDto
            {
                Ok = true,
                Profesionales = CitasRepository.ObtenerEspecialistas(),
                Tipos = CitasRepository.ObtenerCatTiposCita(),
                Estados = CitasRepository.ObtenerEstadosCita()
            };
        }

        public static CitasSemanaDto ObtenerCitasSemana(string fecha)
        {
            DateTime f;
            if (!DateTime.TryParseExact(fecha, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f))
                f = DateTime.Today;
            var lunes = LunesDe(f);
            var hasta = lunes.AddDays(7);

            var citas = CitasRepository.ObtenerCitasAgendadas(lunes, hasta)     // incluye los días pasados de la semana
                .Where(c => c.Inicio >= lunes && c.Inicio < hasta)
                .OrderBy(c => c.Inicio)
                .Select(c => new CitaAgendadaDto
                {
                    Id = c.Id,
                    Fecha = c.Inicio.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
                    Hora = c.Inicio.ToString("HH:mm", CultureInfo.InvariantCulture),
                    Profesional = c.Profesional,
                    TipoCita = c.TipoCita,
                    Paciente = c.Paciente
                }).ToList();

            return new CitasSemanaDto { Ok = true, Lunes = lunes.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), Citas = citas };
        }

        public static DetalleResultadoDto ObtenerCita(long id)
        {
            if (id <= 0) return new DetalleResultadoDto { Ok = false, Mensaje = "Cita inválida." };
            var d = CitasRepository.ObtenerDetalle(id);
            if (d == null) return new DetalleResultadoDto { Ok = false, Mensaje = "La cita no existe." };

            DateTime f = DateTime.ParseExact(d.Fecha, "yyyy-MM-dd", CultureInfo.InvariantCulture);
            TimeSpan apertura, cierre;
            Horario(f.DayOfWeek, d.IdTipoCita == TipoExpressId, out apertura, out cierre);
            d.HoraCierre = cierre.ToString(@"hh\:mm");
            return new DetalleResultadoDto { Ok = true, Cita = d };
        }

        public static ResultadoDto ActualizarCita(CitaUpdateRequest req)
        {
            // El estado ya no se elige en el formulario: si cambia la fecha u hora, la cita pasa a "Reprogramada" (EXP_SP_CitaUpdate)
            if (req == null || req.Cita <= 0 || req.Profesional <= 0)
                return Error("Seleccione el profesional.");

            DateTime fecha;
            if (!DateTime.TryParseExact(req.Fecha, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out fecha))
                return Error("Fecha inválida.");
            TimeSpan hora;
            if (!TimeSpan.TryParseExact(req.Hora, @"hh\:mm", CultureInfo.InvariantCulture, out hora))
                return Error("Hora inválida.");

            // Todo se valida contra los datos del servidor, no contra lo que envía el navegador
            var d = CitasRepository.ObtenerDetalle(req.Cita);
            if (d == null) return Error("La cita no existe.");
            var prof = CitasRepository.ObtenerEspecialistas().FirstOrDefault(x => x.Id == req.Profesional);
            if (prof == null) return Error("El profesional seleccionado no es válido.");

            var inicioOriginal = DateTime.ParseExact(d.Fecha + " " + d.Hora, "yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture);
            int duracion = (d.DuracionMin >= 1 && d.DuracionMin <= 600) ? d.DuracionMin : PasoMin;   // se conserva la duración original
            bool express = d.IdTipoCita == TipoExpressId;

            var inicio = fecha.Date + hora;
            var fin = inicio.AddMinutes(duracion);           // solo minutos
            bool cambioHorario = inicio != inicioOriginal;

            if (cambioHorario)
            {
                TimeSpan apertura, cierre;
                Horario(fecha.DayOfWeek, express, out apertura, out cierre);
                if (hora < apertura || hora + TimeSpan.FromMinutes(duracion) > cierre)
                    return Error("El horario debe estar entre las " + Formato.Hora(apertura) + " y las " + Formato.Hora(cierre) + " (duración " + duracion + " min).");
                if (((hora - apertura).TotalMinutes % PasoMin) != 0)
                    return Error("Seleccione una hora en punto.");
                var limite = express ? inicio.AddMinutes(PasoMin) : inicio;
                if (limite <= DateTime.Now) return Error("Seleccione un horario futuro.");
            }

            if (ValidarChoqueProfesional && (cambioHorario || req.Profesional != d.IdEspecialista))
            {
                bool choque = CitasRepository.ObtenerCitasAgendadas(null, null, 0).Any(c =>      // todas las sucursales
                    c.Id != req.Cita &&
                    string.Equals(c.Profesional, prof.Texto, StringComparison.OrdinalIgnoreCase) &&
                    c.Inicio >= inicio && c.Inicio < fin);
                if (choque) return Error("El profesional ya tiene una cita en ese horario.");
            }

            try
            {
                CitasRepository.ActualizarCita(req.Cita, req.Profesional, null, inicio, fin, UsuarioActual(req.Usuario));
            }
            catch (System.Data.SqlClient.SqlException ex) when (ex.Class == 16)
            {
                // Errores de negocio lanzados por el SP (RAISERROR/THROW) se muestran tal cual
                return Error(ex.Message);
            }
            return new ResultadoDto
            {
                Ok = true, CitaId = (int)Math.Min(req.Cita, int.MaxValue),
                Mensaje = cambioHorario ? "Cita reprogramada para el " + Formato.FechaHora(inicio) + "." : "Cita actualizada correctamente."
            };
        }

        /// <summary>Cancela la cita: queda "Cancelada", libera la hora y al especialista y sale del calendario.</summary>
        public static ResultadoDto CancelarCita(long cita, string motivo, string usuario)
        {
            if (cita <= 0) return Error("La cita no existe.");
            motivo = (motivo ?? "").Trim();
            if (motivo.Length < 5) return Error("Escriba el motivo de la cancelación (al menos 5 caracteres).");
            if (motivo.Length > 250) motivo = motivo.Substring(0, 250);
            try
            {
                decimal saldo = CitasRepository.CancelarCita(cita, motivo, UsuarioActual(usuario));
                return new ResultadoDto
                {
                    Ok = true, CitaId = (int)Math.Min(cita, int.MaxValue),
                    Mensaje = "Cita cancelada: la hora y el especialista quedaron libres."
                        + (saldo > 0 ? " Lo pagado por adelantado ($" + saldo.ToString("N2", CultureInfo.InvariantCulture) + ") queda a favor del paciente." : "")
                };
            }
            catch (System.Data.SqlClient.SqlException ex) when (ex.Number >= 50000)
            {
                return Error(ex.Message);
            }
        }

        public static BusquedaDto BuscarPacientes(int tipo, string termino, string user)
        {
            termino = (termino ?? "").Trim();
            if (tipo != 1 && tipo != 2) return new BusquedaDto { Ok = false, Mensaje = "Seleccione el tipo de búsqueda." };
            if (termino.Length < 3) return new BusquedaDto { Ok = false, Mensaje = "Escriba al menos 3 caracteres." };
            if (termino.Length > (tipo == 2 ? 20 : 100)) return new BusquedaDto { Ok = false, Mensaje = "El texto de búsqueda es demasiado largo." };

            var lista = CitasRepository.BuscarPacientes(tipo, termino, UsuarioActual(user));
            return new BusquedaDto
            {
                Ok = true,
                Pacientes = lista.Take(25).ToList(),
                Mensaje = lista.Count > 25 ? "Se muestran los primeros 25 resultados. Refine la búsqueda." : ""
            };
        }

        public static ResultadoDto CrearCita(CitaRequest req)
        {
            if (req == null) return Error("Solicitud inválida.");

            req.Notas = string.IsNullOrWhiteSpace(req.Notas) ? null : req.Notas.Trim();
            if (req.Notas != null && req.Notas.Length > 300) return Error("Las notas no pueden superar 300 caracteres.");
            if (req.TratamientoIds == null || req.TratamientoIds.Count == 0) return Error("Seleccione al menos un tratamiento.");
            if (req.PacienteCodigo == 0) return Error("Seleccione un paciente.");

            // El paciente se vuelve a consultar en el servidor: no se confía en los datos enviados por el navegador
            string user = UsuarioActual(req.Usuario);
            string doc = (req.Documento ?? "").Trim();
            var candidatos = doc.Length > 0
                ? CitasRepository.BuscarPacientes(2, doc, user)
                : CitasRepository.BuscarPacientes(1, (req.PacienteNombre ?? "").Trim(), user);
            var pac = candidatos.FirstOrDefault(x => x.Codigo == req.PacienteCodigo);
            if (pac == null) return Error("No se pudo validar al paciente. Búsquelo nuevamente.");

            // El tipo de cita se valida contra el SP (no se confía en el nombre enviado por el navegador)
            var tipo = CitasRepository.ObtenerTiposCita(user).FirstOrDefault(x => x.Id == req.TipoCitaId);
            if (tipo == null) return Error("Seleccione un tipo de cita válido.");

            bool express = tipo.Id == TipoExpressId;

            // El profesional debe atender en la sucursal de la sesión (Opciones > Sucursales)
            if (!CitasRepository.ObtenerProfesionales().Any(p => p.Id == req.ProfesionalId))
                return Error("El profesional seleccionado no atiende en esta sucursal.");

            DateTime fecha;
            if (!DateTime.TryParseExact(req.Fecha, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out fecha))
                return Error("Fecha inválida.");
            TimeSpan hora;
            if (!TimeSpan.TryParseExact(req.Hora, @"hh\:mm", CultureInfo.InvariantCulture, out hora))
                return Error("Hora inválida.");

            var ids = req.TratamientoIds.Distinct().Take(15).ToList();
            var tratamientos = CitasRepository.ObtenerTratamientos(ids);
            if (tratamientos.Count != ids.Count)
            {
                //var faltan = ids.Except(tratamientos.Select(t => t.Id)).ToList();
                return Error("Tratamientos no disponibles.");
            }

            // El precio y la duración SIEMPRE se calculan en el servidor
            int duracion = Redondear(tratamientos.Sum(t => t.DuracionMin));
            decimal total = tratamientos.Sum(t => t.Precio);

            TimeSpan apertura, cierre;
            Horario(fecha.DayOfWeek, express, out apertura, out cierre);
            bool alineada = hora >= apertura && ((hora - apertura).TotalMinutes % PasoMin) == 0;
            if (!alineada || hora + TimeSpan.FromMinutes(duracion) > cierre)
                return Error("El horario seleccionado no es válido para la duración del tratamiento.");

            // Inicio = día (00:00) + hora del día. Fin = inicio + SOLO minutos (nunca días).
            var inicio = fecha.Date + hora;
            // Express, o la hora en curso liberada por una cita ya cobrada, permiten la hora en curso
            bool liberada = HoraEnCursoLiberada(CitasRepository.ObtenerOcupados(req.ProfesionalId, inicio, inicio.AddMinutes(PasoMin), true), inicio, DateTime.Now);
            var limiteInicio = express || liberada ? inicio.AddMinutes(PasoMin) : inicio;

            if (limiteInicio <= DateTime.Now) return Error("Seleccione un horario futuro.");
            var fin = inicio.AddMinutes(duracion);
            System.Diagnostics.Trace.TraceInformation("CrearCita inicio={0:yyyy-MM-dd HH:mm} duracion={1} min fin={2:yyyy-MM-dd HH:mm}", inicio, duracion, fin);
            if (duracion <= 0 || duracion > 600 || fin.Date != inicio.Date)
                return Error("La duración de los tratamientos no es válida para un mismo día (" + duracion + " min).");

            bool sobrecupo = EsHoraEnCursoExpress(express, inicio, DateTime.Now);    // Express en la hora en curso: no valida choque
            long id = CitasRepository.CrearCita(req, inicio, fin, total, tratamientos, pac, tipo, user, sobrecupo);
            if (id == 0) return Error("Ese horario acaba de ser tomado. Por favor elija otro.");

            // Se guarda el precio de lista; el descuento del tratamiento se aplica al cobrar. Al usuario se le informa el total con descuento.
            decimal conDescuento = tratamientos.Sum(t => t.Precio - Facturacion.DescuentosTratamiento.Monto(t.Precio, t.Descuento));
            return new ResultadoDto { Ok = true, CitaId = id, Total = conDescuento, Mensaje = "¡Cita registrada correctamente!" };
        }

        private static ResultadoDto Error(string msg)
        {
            return new ResultadoDto { Ok = false, Mensaje = msg };
        }
    }
}
