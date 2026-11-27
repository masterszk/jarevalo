<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_CitasAgenda.aspx.cs" Inherits="DPieCenter.Registros.frm_CitasAgenda" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Agende su cita | <%= NombreClinica %></title>
    <meta name="description" content="Agende su cita podológica en línea: elija tratamiento, día y hora disponibles." />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
    <link href="Registros/css/citas.css" rel="stylesheet" />
</head>
<body>
<form id="form1" runat="server" onsubmit="return false;">

    <div class="page-breadcrumb d-none d-sm-flex align-items-center mb-3">
    <div class="breadcrumb-title pe-3">
	    Agendar Cita
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
</div>

    <main id="top">
        <div class="wrap wiz-wrap">
            <section class="card wizard" aria-label="Asistente para agendar cita">

                <ol class="steps" id="steps">
                    <li data-step="1"><span class="n">1</span><span class="t">Paciente</span></li>
                    <li data-step="2"><span class="n">2</span><span class="t">Tratamientos</span></li>
                    <li data-step="3"><span class="n">3</span><span class="t">Fecha y hora</span></li>
                    <li data-step="4"><span class="n">4</span><span class="t">Confirmar</span></li>
                </ol>

                <!-- PASO 1: PACIENTE -->
                <div class="step-panel" data-step="1">
                    <h2>Buscar paciente</h2>
                    <div class="search-row">
                        <div class="field">
                            <label for="selTipo">Buscar por</label>
                            <select id="selTipo">
                                <option value="1">Nombre</option>
                                <option value="2">Documento</option>
                            </select>
                        </div>
                        <div class="field grow">
                            <label for="txtBuscar" id="lblBuscar">Nombre del paciente</label>
                            <input id="txtBuscar" type="text" maxlength="100" autocomplete="off" />
                        </div>
                        <button type="button" class="btn btn-primary" id="btnBuscar">Buscar</button>
                    </div>
                    <p class="msg" id="busMsg" role="status"></p>
                    <ul class="pac-list" id="lstPacientes" aria-label="Resultados de la búsqueda"></ul>
                </div>

                <!-- PASO 2: TRATAMIENTOS -->
                <div class="step-panel" data-step="2" hidden>
                    <h2>Seleccione los tratamientos</h2>
                    <p class="muted">Puede combinar varios. La duracion total ajusta los horarios disponibles.</p>
                    <div class="trat-grid" id="tratGrid"></div>
                    <div class="trat-bar" id="barTrat" aria-live="polite">Aún no agrega tratamientos.</div>
                </div>

                <!-- PASO 3: FECHA Y HORA -->
                <div class="step-panel" data-step="3" hidden>
                    <h2>Elija el dia y la hora</h2>
                    <div class="agenda-bar">
                        <div class="field">
                            <label for="selTipoCita">Tipo de cita</label>
                            <select id="selTipoCita"></select>
                        </div>
                        <div class="field">
                            <label for="selProfesional">Profesional</label>
                            <select id="selProfesional"></select>
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
                    <p class="note" id="noteExpress" hidden>Cita Express: la hora en curso siempre está disponible, aunque el profesional ya tenga una cita en esa hora. Hay atención hasta las 06:00 PM.</p>
                    <ul class="legend" aria-hidden="true">
                        <li><i class="dot dot-free"></i> Disponible</li>
                        <li><i class="dot dot-busy"></i> Agendado</li>
                        <li><i class="dot dot-sel"></i> Su seleccion</li>
                    </ul>
                    <div class="cal-scroll">
                        <div class="cal-grid" id="calGrid" aria-busy="true"></div>
                    </div>
                </div>

                <!-- PASO 4: CONFIRMAR -->
                <div class="step-panel" data-step="4" hidden>
                    <h2>Confirme la cita</h2>
                    <dl class="confirm" id="confirmList"></dl>
                    <div class="field">
                        <label for="txtNotas">Notas (opcional, sin informacion clinica sensible)</label>
                        <textarea id="txtNotas" rows="2" maxlength="300"></textarea>
                    </div>
                </div>

                <p class="msg" id="wizMsg" role="alert"></p>
                <div class="wiz-foot">
                    <button type="button" class="btn btn-ghost" id="btnAnterior" hidden>&#8249; Anterior</button>
                    <span class="spacer"></span>
                    <button type="button" class="btn btn-primary" id="btnSiguiente">Siguiente &#8250;</button>
                    <button type="button" class="btn btn-success" id="btnConfirmar" hidden>Confirmar cita</button>
                </div>
            </section>
        </div>
    </main>

    <%--<div class="toast" id="toast" role="status" aria-live="polite" hidden></div>--%>
</form>

<script>
    // URL base de los WebMethods (frm_CitasAgenda.aspx/NombreMetodo)
    window.CITAS_URL = '<%= ResolveUrl("frm_CitasAgenda.aspx") %>';
</script>
<%-- Usa el jQuery de Default.aspx. Cargar otra copia aquí reemplazaba la global y rompía $(...).modal() en las demás pantallas. --%>
<script src="Registros/js/citas.js?v=6"></script>
</body>
</html>
