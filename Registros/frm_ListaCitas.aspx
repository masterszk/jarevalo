<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_ListaCitas.aspx.cs" Inherits="DPieCenter.Registros.frm_ListaCitas" %>

<!DOCTYPE html>

<!--breadcrumb-->
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
		    <button type="button" class="btn btn-primary" onclick = "mtd_LimpiarCita();"><i class="lni lni-plus"></i> Agregar</button>
	    </div>
    </div>
</div>


<h6 class="mb-0 text-uppercase">HOY</h6>
<hr/>
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-4" id="listhoy">
	
</div>
<!--end row-->

<h6 class="mb-0 text-uppercase">MAÑANA</h6>
<hr/>
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-4" id="listmanana">
	
</div>
<!--end row-->

<h6 class="mb-0 text-uppercase">FUTURAS</h6>
<hr/>
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-4" id="listfuturas">
	
</div>
<!--end row-->

<!-- Modal -->
<div class="modal fade" id="modalCita" tabindex="-1" aria-labelledby="exampleModalLabel" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exampleModalLabel2">Editar Cita</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
			</div>
			<div class="modal-body">
                <form class="row g-3">
                    <div class="col-md-6">
				        <label for="tipocita" class="form-label">Tipo de Cita</label>
				        <select class="form-select" data-style="btn btn-link" id="tipocita">
					        <option value="-1">--Seleccione una opcion--</option>
				        </select>
                    </div>
                    <div class="col-md-6">
				        <label for="estatus" class="form-label">Estatus</label>
				        <select class="form-select" data-style="btn btn-link" id="estatus">
					        <option value="-1">--Seleccione una opcion--</option>
				        </select>
                    </div>
					<div class="col-md-6">
						<label for="citafecha" class="form-label">Fecha</label>
						<input type="text" class="form-control datepicker" id="citafecha">
					</div>
                    <div class="col-md-6">
                        <label for="especialista" class="form-label">Especialista</label>
                        <select class="form-select" data-style="btn btn-link" id="especialista">
                            <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>
                    <div class="col-md-6">
						<label for="citahora" class="form-label">Hora de Inicio</label>
						<select class="form-select" data-style="btn btn-link" id="citahora">
							<option value="-1">--Seleccione una opcion--</option>
						</select>
					</div>
                    <%--<div class="col-md-6">
				        <label for="citahora" class="form-label">Hora de Finalización</label>
				        <select class="form-select" data-style="btn btn-link" id="citahorafin">
					        <option value="-1">--Seleccione una opcion--</option>
				        </select>
                    </div>--%>
					
                    
					<div class="col-md-12">
						<label for="comentarios" class="form-label">Comentarios</label>
						<textarea class="form-control" id="comentarios"></textarea>
					</div>
				</form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
				<button type="button" class="btn btn-primary" id="btnCitaSave">Guardar</button>
			</div>
		</div>
	</div>
    <input type="hidden" id="cita" value="0" />
    <input type="hidden" id="ind" value="0" />
</div>

<!-- Modal -->
<div class="modal fade" id="modalNewCita" tabindex="-1" aria-labelledby="exampleModalLabel3" aria-hidden="true">
	<div class="modal-dialog modal-lg">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exampleModalLabel3">Programar Cita</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
			</div>
			<div class="modal-body">
                <form class="row g-3">
                    <div class="col-md-6">
                        <label for="tipocita" class="form-label">Tipo de Cita</label>
                        <select class="form-select" data-style="btn btn-link" id="newtipocita">
				                        <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label for="citafecha" class="form-label">Fecha</label>
                        <input type="text" class="form-control datepicker" id="newcitafecha">
                    </div>
                    <div class="col-md-6">
                        <label for="especialista" class="form-label">Especialista</label>
                        <select class="form-select" data-style="btn btn-link" id="newespecialista">
                            <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>
                    <%--<div class="col-md-4">
                        <label for="estatus" class="form-label">Estatus</label>
                        <select class="form-select" data-style="btn btn-link" id="estatus">
				            <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>--%>
                    <div class="col-md-6">
					    <label for="citahora" class="form-label">Hora de Inicio</label>
					    <select class="form-select" data-style="btn btn-link" id="newcitahora">
						    <option value="-1">--Seleccione una opcion--</option>
					    </select>
				    </div>
                   <%-- <div class="col-md-6">
                        <label for="citahora" class="form-label">Hora de Finalización</label>
                        <select class="form-select" data-style="btn btn-link" id="citahorafin">
				                        <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>--%>
				    <div class="col-md-12">
					    <label for="comentarios" class="form-label">Comentarios</label>
					    <textarea class="form-control" id="newcomentarios"></textarea>
				    </div>
                </form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
				<button type="button" class="btn btn-primary" id="btnNewCitaSave">Guardar</button>
			</div>
		</div>
	</div>
    <input type="hidden" id="exp" value="0" />
</div>


<script type="text/javascript">

    var _fec;
    var _user;

	$(document).ready(function () {

        _fec = "";
        _user = $('#idUser').val();
		mtd_ValidateSession();

        mtd_LeeTiposCitas(6);
        mtd_LeeEstatus(4);
        mtd_LeeEspecialistas(4);

        mtd_LeeCitasVigentesHoy(_user,1);
        mtd_LeeCitasVigentesTomorrow(_user,2);
        mtd_LeeCitasVigentesFuture(_user,3);

        $("#citafecha").flatpickr({
            dateFormat: "d/m/Y",
            ignoreReadonly: true,
            daysOfWeekDisabled: [0],
            minDate: getFirstDay(),
        });

        mtd_LeeHorarios(1, 1, "2025-01-01");
        //mtd_LeeHorariosfin(1, 1, "2025-01-01");

        // $('#especialista').change(function () {
        //     var tipocita = $('#tipocita').val();
        //     var especialista = $('#especialista').val();
        //     var fecha = $('#citafecha').val();



        //     if (especialista == '-1')
        //         showNotification(1, 'error', 'El Especialista es requerido.');
        //     else if (tipocita == '-1')
        //         showNotification(1, 'error', 'El Tipo de Cita es requerido.');
        //     else {
        //         var validaFecha = isTextoVacio(fecha, "Falta FECHA de la cita.");

        //         if (!validaFecha.respuesta) {
        //             mensaje = validaFecha.message;
        //             showNotification(1, 'error', mensaje);
        //         } else {
                    // mtd_LeeHorarios(tipocita, especialista, fecha);
                    // mtd_LeeHorariosfin(tipocita, especialista, fecha);
        //         }
        //     }
        // });

        $('#btnCitaSave').click(function () {
            var id = $('#cita').val();
            var fecha = $('#citafecha').val();
            var horario = $('#citahora').val();
            //var horariofin = $('#citahorafin').val();
            var horariofin = horario;
            var estado = $('#estatus').val();
            var tipocita = $('#tipocita').val();
            var especialista = $('#especialista').val();
            var comentario = $('#comentarios').val();
            var user = $('#idUser').val();
            var accion = 2;
            var ind = $('#ind').val();

            var validaEspecialista = isSelectedValid('especialista', '-1', 'ESPECIALISTA');
            var validaHorario = isSelectedValid('citahora', '-1', 'HORA DE INICIO');
            var validaTipocita = isSelectedValid('tipocita', '-1', 'TIPO DE CITA');
            var validaHorarioFin = isSelectedValid('citahorafin', '-1', 'HORA DE FINAL');

            var validaFecha = isTextoVacio(fecha, "Falta FECHA de la cita.");

            if (!validaFecha.respuesta) {
                mensaje = validaFecha.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaEspecialista.respuesta) {
                mensaje = validaEspecialista.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaHorario.respuesta) {
                mensaje = validaHorario.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaTipocita.respuesta) {
                mensaje = validaTipocita.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaHorarioFin.respuesta) {
                mensaje = validaHorarioFin.message;
                showNotification(1, 'warning', mensaje);
            } else {
                mtd_SaveCita(id, 0, horario, horariofin, tipocita, especialista, 0, estado, comentario, fecha, user, accion, ind);
            }
        });
        
    });

    function mtd_LimpiarCita() {
        $('#newcitafecha').val('');
        $('#newcitahora').val('-1');
        $('#newtipocita').val('-1');
        $('#newespecialista').val('-1');
        $('#newcomentarios').val('');
        $('#total').text('0.00');
        mtd_OpenModal('modalNewCita');
    }
    

    function mtd_SaveCita(id, expediente, horario, horariofin, tipocita, especialista, tratamiento
        , estado, comentario, fecha, user, accion, ind) {
        var a = {
            'id': id, 'expediente': expediente, 'horario': horario, 'horariofin': horariofin, 'tipocita': tipocita
            , 'especialista': especialista, 'tratamiento': tratamiento, 'estado': estado, 'comentario': comentario
            , 'fecha': fecha, 'user': user, 'accion': accion
        };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_SaveCita",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    showNotification(1, 'success', mensaje[1]);
                    mtd_CloseModal('modalCita');

                    if (ind == 1)
                        mtd_LeeCitasVigentesHoy(_user, 1);
                    else if (ind == 2)
                        mtd_LeeCitasVigentesTomorrow(_user, 2);
                    else if (ind == 3)
                        mtd_LeeCitasVigentesFuture(_user, 3)
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeCitasVigentesHoy(user, accion) {
        var a = { 'user': user ,'accion': accion };
		params = JSON.stringify(a);

        WaitProcess('listhoy');

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeCitasVigentesHoy",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");

                $('#listhoy').empty();

                if (mensaje[0] == 'OK') {
                    $('#listhoy').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
	}

    function mtd_LeeCitasVigentesTomorrow(user, accion) {
        var a = { 'user': user, 'accion': accion };
        params = JSON.stringify(a);

        WaitProcess('listmanana');

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeCitasVigentesTomorrow",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                $('#listmanana').empty();
                if (mensaje[0] == 'OK') {
                    $('#listmanana').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
	}

    function mtd_LeeCitasVigentesFuture(user, accion) {
        var a = { 'user': user, 'accion': accion };
        params = JSON.stringify(a);

        WaitProcess('listfuturas');

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeCitasVigentesFuture",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                $('#listfuturas').empty();
                if (mensaje[0] == 'OK') {
                    $('#listfuturas').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeCita(id, accion, ind) {
        var a = { 'id': id, 'accion': accion, 'ind' : ind };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeCita",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#cita').val(id);
                    // mtd_LeeHorarios(mensaje[3], mensaje[4], "2025-01-01");
                    // mtd_LeeHorariosfin(mensaje[3], mensaje[4], "2025-01-01");
                    $('#citahora').val(mensaje[1]);
                    // $('#citahorafin').val(mensaje[2]);
                    $('#tipocita').val(mensaje[3]);
                    $('#especialista').val(mensaje[4]);
                    $('#estatus').val(mensaje[5]);
                    $('#citafecha').val(mensaje[6]);
                    $('#comentarios').val(mensaje[7]);
                    $('#ind').val(ind);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeTiposCitas(accion) {
        var a = { 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeTiposCitas",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#tipocita').empty();
                    $('#tipocita').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeEspecialistas(accion) {
        var a = { 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeEspecialistas",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#especialista').empty();
                    $('#especialista').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }
    
    function mtd_LeeHorarios(tipocita, especialista, fecha) {
        var a = { 'tipocita': tipocita, 'especialista': especialista, 'fecha': fecha };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeHorarios",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#citahora').empty();
                    $('#citahora').html(mensaje[1]);
                    $('#citahora').val(hora);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    // function mtd_LeeHorariosfin(tipocita, especialista, fecha) {
    //     var a = { 'tipocita': tipocita, 'especialista': especialista, 'fecha': fecha };
    //     params = JSON.stringify(a);

    //     $.ajax({
    //         type: "POST",
    //         url: "Registros/frm_ListaCitas.aspx/mtd_LeeHorarios",
    //         data: params,
    //         contentType: "application/json; charset=utf-8",
    //         dataType: "json",
    //         async: true,
    //         success: function (msg) {
    //             var mensaje = msg.d.split("||");
    //             if (mensaje[0] == 'OK') {
    //                 $('#citahorafin').empty();
    //                 $('#citahorafin').html(mensaje[1]);
    //                 $('#citahorafin').val(hora);
    //             }
    //             else
    //                 showNotification(1, 'error', mensaje[1]);
    //         },
    //         error: function (XMLHttpRequest, textStatus, errorThrown) {
    //             showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
    //         }
    //     });
    // }

    function mtd_LeeEstatus(accion) {
        var a = { 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaCitas.aspx/mtd_LeeEstatus",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#estatus').empty();
                    $('#estatus').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

</script>