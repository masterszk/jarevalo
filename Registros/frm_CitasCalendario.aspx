<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_CitasCalendario.aspx.cs" Inherits="DPieCenter.Registros.frm_CitasCalendario" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Agenda de citas | <%= NombreClinica %></title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
    <link href="Registros/css/citas.css" rel="stylesheet" />
    <link href="Registros/css/calendario.css?v=4" rel="stylesheet" />
</head>
<body>
<form id="form1" runat="server" onsubmit="return false;">

    <div class="page-breadcrumb d-none d-sm-flex align-items-center mb-3">
	    <div class="breadcrumb-title pe-3">
		    Registros
	    </div>
	    <div class="ps-3">
		    <nav aria-label="breadcrumb">
			    <ol class="breadcrumb mb-0 p-0">
				    <li class="breadcrumb-item">
					    <a href="javascript:;"><i class="bx bx-calendar"></i></a>
				    </li>
				    <li class="breadcrumb-item active" aria-current="page">Citas</li>
			    </ol>
		    </nav>
	    </div>
        <div class="ms-auto">
	        <div class="btn-group">
		        <button type="button" class="btn btn-primary" onclick = "AjaxLink('Registros/frm_CitasAgenda.aspx');"><i class="lni lni-plus"></i> Agregar</button>
	        </div>
        </div>
    </div>

    <main id="top">
        <div class="wrap cal-wrap">
            <section class="card agenda-cal" aria-label="Agenda semanal de citas">
                <div class="agenda-bar">
                    <div class="field">
                        <label for="selFiltroProf">Profesional</label>
                        <select id="selFiltroProf"><option value="0">Todos</option></select>
                    </div>
                    <!-- Ir directo a un mes (el actual y los 12 siguientes): muestra la primera semana de ese mes -->
                    <div class="field">
                        <label for="selMes">Mes</label>
                        <select id="selMes"></select>
                    </div>
                    <div class="week-nav" role="group" aria-label="Navegar semanas">
                        <button type="button" class="btn btn-ghost" id="btnPrev" aria-label="Semana anterior">&#8249; Anterior</button>
                        <button type="button" class="btn btn-ghost" id="btnHoy">Hoy</button>
                        <button type="button" class="btn btn-ghost" id="btnNext" aria-label="Semana siguiente">Siguiente &#8250;</button>
                    </div>
                    <strong class="week-label" id="lblSemana" aria-live="polite"></strong>
                </div>
                <p class="msg" id="calMsg" role="alert"></p>
                <div class="week-scroll">
                    <div class="week" id="calGrid" aria-busy="true"></div>
                </div>
            </section>
        </div>
    </main>

    <!-- ===== FORMULARIO: MODIFICAR CITA ===== -->
    <div class="modal" id="modalCita" role="dialog" aria-modal="true" aria-labelledby="tituloModal" hidden="true">
        <div class="modal-card modal-wide">
            <h3 id="tituloModal">Modificar cita</h3>
            <dl class="info" id="infoPaciente"></dl>

            <!-- Tratamientos de la cita: solo consulta (no se modifican ni se eliminan desde aquí) -->
            <div class="tratamientos-cita">
                <div class="tratamientos-titulo">Tratamientos de la cita <small class="hint">(solo consulta)</small></div>
                <ul id="lstTratamientos"></ul>
            </div>

            <!-- Pago por adelantado en caja: se conserva al cambiar fecha, hora o profesional -->
            <div class="alert alert-success small py-2" id="avisoAnticipo" hidden></div>
            <!-- Pago adelantado sin cita del paciente (monto libre): se usa en esta cita con el botón -->
            <div class="alert alert-primary small py-2" id="avisoPagoAdelantado" hidden>
                <div class="d-flex flex-wrap align-items-center gap-2">
                    <span id="txtPagoAdelantado" class="me-auto"></span>
                    <button type="button" class="btn btn-sm btn-primary" id="btnUsarPago">Usar pago adelantado</button>
                </div>
            </div>

            <div class="grid-2">
                <div class="field">
                    <label for="selProfesional">Profesional</label>
                    <select id="selProfesional"></select>
                </div>
                <div class="field">
                    <label for="txtDia">Día</label>
                    <input type="date" id="txtDia" />
                </div>
                <div class="field">
                    <label for="selHora">Hora</label>
                    <select id="selHora"></select>
                </div>
                <div class="field">
                    <label>Duración</label>
                    <div class="static" id="lblDuracion"></div>
                </div>
            </div>
            <small class="hint">Si cambia el día o la hora, la cita queda como <strong>Reprogramada</strong> y se sigue atendiendo en Procedimientos.</small>

            <p class="msg" id="modalMsg" role="alert"></p>
            <div class="modal-actions">
                <!-- Cancela la cita (pide el motivo): libera la hora y al especialista -->
                <button type="button" class="btn btn-danger me-auto" id="btnCancelarCita">Cancelar cita</button>
                <button type="button" class="btn btn-ghost" id="btnCancelar">Cerrar</button>
                <button type="button" class="btn btn-success" id="btnGuardar">Guardar cambios</button>
            </div>
        </div>
    </div>

    <div class="toast" id="toast" role="status" aria-live="polite" hidden></div>
</form>

<script>
    // URL base de los WebMethods (frm_CitasCalendario.aspx/NombreMetodo)
    window.CAL_URL = '<%= ResolveUrl("frm_CitasCalendario.aspx") %>';
</script>
<%-- Usa el jQuery de Default.aspx. Cargar otra copia aquí reemplazaba la global y rompía $(...).modal() en las demás pantallas. --%>
<script src="Registros/js/calendario.js?v=12"></script>
</body>
</html>
