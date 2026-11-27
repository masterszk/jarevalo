<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_facCaja.aspx.cs" Inherits="DPieCenter.Facturacion.frm_facCaja" %>

<!--breadcrumb-->
<div class="page-breadcrumb d-none d-sm-flex align-items-center mb-3">
	<div class="breadcrumb-title pe-3">Facturacion</div>
	<div class="ps-3">
		<nav aria-label="breadcrumb">
			<ol class="breadcrumb mb-0 p-0">
				<li class="breadcrumb-item"><a href="javascript:;"><i class="bx bx-list-ol"></i></a>
				</li>
				<li class="breadcrumb-item active" aria-current="page">Caja</li>
			</ol>
		</nav>
	</div>
</div>

<div class="card">
	<div class="card-body" >
		<div class="table-responsive" id="lodaData">
        </div>
	</div>
</div>

<!-- Modal -->
<div class="modal fade" id="modalProcedimientos" tabindex="-1" aria-labelledby="exampleModalLabel" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<h5 class="modal-title" id="exampleModalLabel2">Lista de Procedimientos</h5>
				<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
			</div>
			<div class="modal-body">
                <form class="row g-3" id="listProcess">
					
				</form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
			</div>
		</div>
	</div>
</div>

<script type="text/javascript">
    
    $(document).ready(function () {

        mtd_ValidateSession();

        $("#btnGenerar").click(function () {
            var cliente = $('#paciente').val();
            var fdesde = $('#fdesde').val();
            var hdesde = $('#hdesde').val();
            var fhasta = $('#fhasta').val();
            var hhasta = $('#hhasta').val();
            var especialista = $('#especialista').val();
            var estatus = $('#estatus').val();

            var validaFdesde = isTextoVacio(fdesde, "FECHA DESDE");
            var validaFhasta = isTextoVacio(fhasta, "FECHA HASTA");


            if (!validaFdesde.respuesta) {
                mensaje = validaFdesde.message;
                showNotification(1, 'warning', mensaje);
            } else if (!validaFhasta.respuesta) {
                mensaje = validaFhasta.message;
                showNotification(1, 'warning', mensaje);
            } else {
                mtd_InformePacientes(cliente, fdesde, hdesde, fhasta, hhasta, especialista, estatus, 1);
            }

        });
    });

    function mtd_LeeEspecialistas(accion) {
        var a = { 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Reportes/frm_repReporteProcedimientos.aspx/mtd_LeeEspecialistas",
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

    function mtd_LeeEstatus(accion) {
        var a = { 'accion': accion };
        params = JSON.stringify(a);

        $.ajax({
            type: "POST",
            url: "Reportes/frm_repReporteProcedimientos.aspx/mtd_LeeEstatus",
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
   
    function mtd_InformePacientes(cliente, fdesde, hdesde, fhasta, hhasta, especialista, estatus, accion) {
        var a = {
            'cliente': cliente, 'fdesde': fdesde, 'hdesde': hdesde, 'fhasta': fhasta, 'hhasta': hhasta
            , 'especialista': especialista, 'estatus': estatus, 'accion': accion
        };
        params = JSON.stringify(a);

        WaitProcess('lodaData');

        $.ajax({
            type: "POST",
            url: "Reportes/frm_repReporteProcedimientos.aspx/mtd_InformePacientes",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                var tabla;

                $('#lodaData').empty();

                if (mensaje[0] == "OK") {

                    tabla = '<table class="table table-striped table-bordered" style="width:100%" id="tbProcess">';
                    tabla += '<thead class="table-dark">';
                    tabla += '<tr>';
                    tabla += '<th class=\"text-center\">PACIENTE</th>';
                    tabla += '<th class=\"text-center\">FECHA</th>';
                    tabla += '<th class=\"text-center\">HORA</th>';
                    tabla += '<th class=\"text-center\">ESPECIALISTA</th>';
                    tabla += '<th class=\"text-center\">ESTATUS</th>';
                    tabla += '<th class=\"text-center\">CANTIDAD</th>';
                    tabla += '<th class=\"text-center\">VALOR</th>';
                    tabla += '<th class=\"text-center\">DIAGNOSTICO</th>';
                    tabla += '<th class=\"text-center\">RESULTADO</th>';
                    tabla += '<th class=\"text-center\">TRATAMIENTO</th>';
                    tabla += '</tr>';
                    tabla += '</thead>';
                    tabla += '<tbody>';
                    tabla += mensaje[1];
                    tabla += '</table>';
                    
                    $('#lodaData').html(tabla);

                    var table = $('#tbProcess').DataTable({
                        lengthChange: false,
                        ordering: false,
                        iDisplayLength: 25,
                        buttons: ['excel', 'print']
                    });

                    table.buttons().container()
                        .appendTo('#tbProcess_wrapper .col-md-6:eq(0)');
                }
                else
                    showNotification(1, 'error', mensaje[1]);
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                showNotification(1, 'error', textStatus + ": " + XMLHttpRequest.responseText);
            }
        });
    }

    function mtd_LeeDatostto(cita, accion) {
        var a = {
            'cita': cita,  'accion': accion
        };
        params = JSON.stringify(a);

        WaitProcess('listProcess');

        $.ajax({
            type: "POST",
            url: "Reportes/frm_repReporteProcedimientos.aspx/mtd_LeeDatostto",
            data: params,
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: true,
            success: function (msg) {
                var mensaje = msg.d.split("||");
                var tabla;

                $('#listProcess').empty();

                if (mensaje[0] == "OK") {

                    tabla = '<table class="table table-striped table-bordered" style="width:100%">';
                    tabla += '<thead class="table-dark">';
                    tabla += '<tr>';
                    tabla += '<th class=\"text-center\">PROCEDIMIENTOS</th>';
                    tabla += '<th class=\"text-center\">VALOR</th>';
                    tabla += '</tr>';
                    tabla += '</thead>';
                    tabla += '<tbody>';
                    tabla += mensaje[1];
                    tabla += '</table>';

                    $('#listProcess').html(tabla);
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




