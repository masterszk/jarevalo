<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_ListaProcedimientos.aspx.cs" Inherits="DPieCenter.Registros.frm_ListaProcedimientos" %>


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
					<a href="javascript:void(0)"><i class="bx bx-calendar"></i></a>
				</li>
				<li class="breadcrumb-item active" aria-current="page">Procedimientos</li>
			</ol>
		</nav>
	</div>
</div>


<h6 class="mb-0 text-uppercase">HOY</h6>
<hr/>
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-4" id="listhoy">
	
</div>

<%--<h6 class="mb-0 text-uppercase">FINALIZADOS</h6>
<hr/>
<div class="row row-cols-1 row-cols-md-2 row-cols-xl-4" id="listfinished">
	
</div>--%>

<!-- Modal -->
<div class="modal fade" id="modalReprogramar" tabindex="-1" aria-labelledby="exampleModalLabel" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exampleModalLabel">Reprogramar Cita</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
			</div>
			<div class="modal-body">
                <form class="row g-3">
                    <div class="col-md-6">
                        <label for="tipocita" class="form-label">Tipo de Cita</label>
                        <select class="form-select" data-style="btn btn-link" id="reprotipocita">
                                        <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label for="estatus" class="form-label">Estatus</label>
                        <select class="form-select" data-style="btn btn-link" id="reproestatus">
                            <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label for="citafecha" class="form-label">Fecha</label>
                        <input type="text" class="form-control datepicker" id="reprofecha">
                    </div>
                    <div class="col-md-6">
                        <label for="especialista" class="form-label">Especialista</label>
                        <select class="form-select" data-style="btn btn-link" id="reproespecialista">
                            <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label for="citahora" class="form-label">Hora de Inicio</label>
                        <select class="form-select" data-style="btn btn-link" id="reprohora">
				                        <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>
                    <%--<div class="col-md-6">
                        <label for="citahora" class="form-label">Hora de Finalización</label>
                        <select class="form-select" data-style="btn btn-link" id="reprohorafin">
                                        <option value="-1">--Seleccione una opcion--</option>
                        </select>
                    </div>--%>
                    <div class="col-md-12">
                        <label for="comentarios" class="form-label">Comentarios</label>
                        <textarea class="form-control" id="reprocomentarios"></textarea>
                    </div>
                </form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
				<button type="button" class="btn btn-primary" id="btnReprograma">Guardar</button>
			</div>
		</div>
	</div>
    <input type="hidden" id="idcita" value="0" />
    <input type="hidden" id="idproces" value="0" />
</div>

<div class="modal fade" id="modalPrecedimientos" tabindex="-1" aria-labelledby="exampleModalLabel1" aria-hidden="true">
	<div class="modal-dialog modal-fullscreen">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exampleModalLabel1">Programar Cita</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
			</div>
			<div class="modal-body">
                <div class="row">
					<div class="col-sm-4">
						<div class="row">
							<div class="col-sm-12">
								<div class="card radius-10 w-100">
									<div class="product-list p-3 mb-3" id="loadProcess">
										
									</div>
								</div>
							</div>
							<div class="col-md-12">
								<div class="card">
									<div class="card-body">
										<form class="row g-3">
											<div class="col-md-4">
                                                <h3>Total</h3>
                                            </div>
                                            <div class="col-md-8" style="text-align:right;">
                                                <h3 id="total"></h3> 
                                            </div>
										</form>
									</div>
								</div>
                            </div>
						</div>
					</div>
                    <div class="col-md-8">
                        <form class="row g-3">
							<div class="card">
								<div class="card-body">
									<div class="row row-cols-1 row-cols-sm-2 row-cols-lg-3 row-cols-xl-4 row-cols-xxl-5 product-grid" id="loadProducts">
										
									</div><!--end row-->
								</div>
							</div>
                        </form>
                    </div>
                </div>
			</div>
		</div>
	</div>
</div>

<div class="modal fade" id="modalFinalizacion" tabindex="-1" aria-labelledby="exampleModalLabel2" aria-hidden="true">
	<div class="modal-dialog modal-fullscreen">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exampleModalLabel2">Finalizar Cita</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
			</div>
			<div class="modal-body">
                <div class="row">
					<div class="col-sm-12">
						<div class="card radius-10 w-100">
                            <div class="card-body">
                                <div class="card-title">
                                    <h5 class="mb-8">Diagnostico</h5>
                                    <hr />
                                    <div class="row">
					                    <div class="col-sm-12">
                                            <input type="hidden" id="proccess" value="0"/>
                                            <input type="hidden" id="ciita" value="0"/>
                                            <input type="hidden" id="acccion" value="1"/>
                                            <textarea rows="5" class="form-control" id="diagnostico"></textarea>
                                        </div>
                                    </div>
                                </div>
                            </div>
						</div>
					</div>
                    <div class="col-sm-12">
						<div class="card radius-10 w-100">
                            <div class="card-body">
                                <div class="card-title">
                                    <h5 class="mb-8">Resultados</h5>
                                    <hr />
                                    <div class="row">
					                    <div class="col-sm-12">
                                            <textarea rows="5" class="form-control" id="resultado"></textarea>
                                        </div>
                                    </div>
                                </div>
                            </div>
						</div>
					</div>
                    <div class="col-sm-12">
						<div class="card radius-10 w-100">
                            <div class="card-body">
                                <div class="card-title">
                                    <h5 class="mb-8">Recomentaciones</h5>
                                    <hr />
                                    <div class="row">
					                    <div class="col-sm-12">
                                            <textarea rows="5" class="form-control" id="recomendacion"></textarea>
                                        </div>
                                    </div>
                                </div>
                            </div>
						</div>
					</div>
                </div>
			</div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-primary" id="btnFinished">Guardar</button>
            </div>
		</div>
	</div>
</div>



<script type="text/javascript">

    var _fec = "";

	$(document).ready(function () {

		mtd_ValidateSession();

        mtd_LeeCitasVigentesHoy($('#idUser').val(), 4);

        mtd_LeeTiposCitas(6);
        mtd_LeeEstatus(6);
        mtd_LeeEspecialista(6);
        mtd_LeeHorarios('2', '10003', '01/01/2025','-1');
        // mtd_LeeHorariosFin('2', '10003', '01/01/2025','-1');

        $("#reprofecha").flatpickr({
            dateFormat: "d/m/Y",
            ignoreReadonly: true,
            daysOfWeekDisabled: [0],
            minDate: getFirstDay(),
        });



        $('#btnReprograma').click(function () {
            var id = $('#idproces').val();
            var cita = $('#idcita').val();
            var tipocita = $('#reprotipocita').val();
            var fecha = $('#reprofecha').val();
            var hora = $('#reprohora').val();
            //var horariofin = $('#reprohorafin').val();
            var horariofin = hora;
            var especialista = $('#reproespecialista').val();
            var estatus = $('#reproestatus').val();
            var comentario = $('#reprocomentarios').val();
            var user = $('#idUser').val();
            var accion = '4';

            var validaId = isTextoVacio(id, 'Haca falta ID del registro.');
            var validaFecha = isTextoVacio(fecha, 'Haca falta FECHA de la cita.');
            var validaHora = isSelectedValid('reprohora', '-1', 'Hace falta HORA de INICIO de la cita');
            //var validaHoraFin = isSelectedValid('reprohorafin', '-1', 'Hace falta HORA FINAL de la cita');
            var validaEspecialista = isSelectedValid('reproespecialista', '-1', 'Hace falta ESPECIALISTA');
            var validaEstatus = isSelectedValid('reproestatus', '-1', 'Hace falta ESTATUS de la cita');
            var validaTipocita = isSelectedValid('reprotipocita', '-1', 'Hace falta TIPO DE CITA');

            if (!validaId.respuesta) {
                mensaje = validaId.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaFecha.respuesta) {
                mensaje = validaFecha.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaHora.respuesta) {
                mensaje = validaHora.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaEspecialista.respuesta) {
                mensaje = validaEspecialista.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaEstatus.respuesta) {
                mensaje = validaEstatus.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaTipocita.respuesta) {
                mensaje = validaTipocita.message;
                showNotification(1, 'warning', mensaje);
            } else {
                mtd_SaveReprogramaCita(id, cita, especialista, estatus, fecha, hora, horariofin, tipocita, comentario, user, accion)
            }
        });

        $('#btnFinished').click(function () {

            var id = $('#proccess').val();
            var cita = $('#ciita').val();
            var diagnostico = $('#diagnostico').val();
            var resultado = $('#resultado').val();
            var recomendacion = $('#recomendacion').val();
            var accion = $('#acccion').val();
            var user = $('#idUser').val();

            var validaDiagnostico = isTextoVacio(diagnostico, 'Haca falta el DIAGNOSTICO.');
            var validaResultado = isTextoVacio(resultado, 'Haca falta el RESULTADO.');
            var validaRecomendacion = isTextoVacio(recomendacion, 'Haca falta la RECOMENDACION.');

            if (!validaDiagnostico.respuesta) {
                mensaje = validaDiagnostico.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaResultado.respuesta) {
                mensaje = validaResultado.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaRecomendacion.respuesta) {
                mensaje = validaRecomendacion.message;
                showNotification(1, 'warning', mensaje);
            } else {
                mtd_FinishedProcess(id, cita, diagnostico, resultado, recomendacion, user, accion);
            }
            
        });

    });


    function mtd_LeeCitasVigentesHoy(user, accion) {
        var a = { 'user': user, 'accion': accion };
        params = JSON.stringify(a);

        WaitProcess('listhoy');

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeCitasVigentesHoy",
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

    function mtd_LeeCitasFinalizadas(user ,accion) {
        var a = { 'user': user, 'accion': accion };
        params = JSON.stringify(a);

        WaitProcess('listfinished');

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeCitasFinalizadas",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");

                $('#listfinished').empty();

                if (mensaje[0] == 'OK') {
                    $('#listfinished').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeHorarios(tipocita, especialista, fecha, hora) {
        var a = { 'tipocita': tipocita, 'especialista': especialista, 'fecha': fecha };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeHorarios",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#reprohora').empty();
                    $('#reprohora').html(mensaje[1]);
                    $('#reprohora option').each(function () { $(this).text(hora12($(this).text())); });   // texto en 12 h; el valor no cambia
                    $('#reprohora').val(hora);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }


    // function mtd_LeeHorariosFin(tipocita, especialista, fecha, hora) {
    //     var a = { 'tipocita': tipocita, 'especialista': especialista, 'fecha': fecha };
    //     params = JSON.stringify(a);

    //     $.ajax({
    //         type: "POST",
    //         url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeHorarios",
    //         data: params,
    //         contentType: "application/json; charset=utf-8",
    //         dataType: "json",
    //         async: true,
    //         success: function (msg) {
    //             var mensaje = msg.d.split("||");
    //             if (mensaje[0] == 'OK') {
    //                 $('#reprohorafin').empty();
    //                 $('#reprohorafin').html(mensaje[1]);
    //                 $('#reprohora').val(hora);
    //             }
    //             else
    //                 showNotification(1, 'error', mensaje[1]);
    //         },
    //         error: function (XMLHttpRequest, textStatus, errorThrown) {
    //             showNotification('top-center', 'error', textStatus + ": " + XMLHttpRequest.responseText);
    //         }
    //     });
    // }

    function mtd_LeeTiposCitas(accion) {
        var a = { 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaExpedientes.aspx/mtd_LeeTiposCitas",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#reprotipocita').empty();
                    $('#reprotipocita').html(mensaje[1]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeEstatus(accion) {
        var a = {'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeEstatus",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#reproestatus').empty();
                    $('#reproestatus').html(mensaje[1]);
                    $('#reproestatus').val('-1');
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeEspecialista(accion) {
        var a = { 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeEspecialista",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#reproespecialista').empty();
                    $('#reproespecialista').html(mensaje[1]);
                    $('#reproespecialista').val('-1');
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_ReprogramaCita(id, proces, accion) {
        var a = { 'id': id, 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_ReprogramaCita",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    $('#idcita').val(id);
                    $('#idproces').val(proces);
                    $('#reprofecha').val(mensaje[2]);
                    $('#reprohora').val(mensaje[3]);
                    $('#reproespecialista').val(mensaje[4]);
                    $('#reproestatus').val(mensaje[5]);
                    $('#reprocomentarios').val(mensaje[6]);
                    //$('#reprohorafin').val(mensaje[7]);
                    $('#reprotipocita').val(mensaje[8]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_SaveReprogramaCita(id, cita, especialista, estatus, fecha, hora, horariofin, tipocita, comentario, user, accion) {
        var a = {
            'id': id, 'cita': cita, 'estatus': estatus, 'especialista': especialista, 'fecha': fecha, 'hora': hora
            , 'horariofin': horariofin, 'tipocita': tipocita, 'comentario': comentario, 'user': user, 'accion': accion
        };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_SaveReprogramaCita",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    showNotification(1, 'seccess', mensaje[1]);
                    mtd_LeeCitasVigentesHoy(user, 4);
                    mtd_CloseModal("modalReprogramar");
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeTratamientos(cita, user, accion) {
        var a = { 'cita': cita, 'user': user, 'accion': accion };
        params = JSON.stringify(a);

        WaitProcess('loadProducts');

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeTratamientos",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                $('#loadProducts').empty();

                if (mensaje[0] == "OK") {
                    $('#loadProducts').html(mensaje[1]);
                    mtd_LeeTratamientosByProccess(cita, user, 2);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeTratamientosByProccess(cita, user, accion) {
        var a = { 'cita': cita, 'user': user, 'accion': accion };
        params = JSON.stringify(a);

        WaitProcess('loadProcess');

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_LeeTratamientosByProccess",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                $('#loadProcess').empty();

                if (mensaje[0] == "OK") {
                    $('#loadProcess').html(mensaje[1]);
                    $('#total').text(mensaje[2]);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }
            
    function mtd_SaveTtoByProccess(cita, procedimiento, user, accion) {
        var a = { 'cita': cita, 'tratamiento': procedimiento, 'user': user, 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_SaveTtoByProccess",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == "OK") {
                    showNotification(1, 'success', mensaje[1]);
                    mtd_LeeTratamientosByProccess(cita, user, 2);
                    mtd_LeeCitasVigentesHoy(user, 4);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                alert(textStatus + ": " + XMLHttpRequest.responseText);
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_DeleteByTratamientos(id, accion, cita) {
        var a = { 'id': id, 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_DeleteByTratamientos",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == "OK") {
                    showNotification(1, 'success', mensaje[1]);
                    var user = $('#idUser').val();
                    mtd_LeeTratamientosByProccess(cita, user, 2);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_AsigaValoresProccess(cita) {
        var a = { 'cita': cita };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_AsigaValoresProccess",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == "OK") {
                    if (mensaje[1] != "0") {
                        $('#proccess').val(mensaje[2]);
                        $('#ciita').val(cita);
                        $('#diagnostico').val(mensaje[3]);
                        $('#resultado').val(mensaje[4]);
                        $('#recomendacion').val(mensaje[5]);
                        $('#acccion').val('2');
                    }
                    else {
                        $('#proccess').val('0');
                        $('#ciita').val(cita);
                        $('#diagnostico').val('');
                        $('#resultado').val('');
                        $('#recomendacion').val('');
                        $('#acccion').val('1');
                    }
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                alert(textStatus + ": " + XMLHttpRequest.responseText);
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_FinishedProcess(id, cita, diagnostico, resultado, recomendacion, user, accion) {
        var a = {
            'id': id, 'cita': cita, 'diagnostico': diagnostico, 'resultado': resultado
            , 'recomendacion': recomendacion, 'user': user, 'accion': accion
        };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_FinishedProcess",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == "OK") {
                    mtd_CloseModal('modalFinalizacion');
                    showNotification(1, 'success', mensaje[1]);
                    mtd_LeeCitasVigentesHoy(user, 4);
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_ProcessCancelar(cita, user) {
        var a = { 'cita': cita, 'user': user };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Registros/frm_ListaProcedimientos.aspx/mtd_ProcessCancelar",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                if (mensaje[0] == 'OK') {
                    showNotification(1, 'seccess', mensaje[1]);
                    mtd_LeeCitasVigentesHoy(user, 4);
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