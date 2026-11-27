<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_Apertura.aspx.cs" Inherits="DPieCenter.Facturacion.frm_Apertura" %>

<!--breadcrumb-->
<div class="page-breadcrumb d-none d-sm-flex align-items-center mb-3">
	<div class="breadcrumb-title pe-3">Facturacion</div>
	<div class="ps-3">
		<nav aria-label="breadcrumb">
			<ol class="breadcrumb mb-0 p-0">
				<li class="breadcrumb-item"><a href="javascript:;"><i class="lni lni-users"></i></a>
				</li>
				<li class="breadcrumb-item active" aria-current="page">Apertura de Caja</li>
			</ol>
		</nav>
	</div>
</div>

<div class="row" id="loadAperturas">
    <div class="col-md-6">
        <div class="card" style="margin-top:20px;height:120px;">
	        <div class="card-body" >
		        <form class="row g-3">
			        <div class="col-md-4">
                            <input type="hidden" id="codigo" value="0">
			                <button type="button" style="margin-top:20px;width:120px;" class="btn btn-primary" id="btnApertura"></button>
			        </div>
                    <div class="col-md-4">
                        <div class="row">
                            <div class="col-md-12" style="margin-top:15px;">             
				                <label class="form-label" id="lblfecha"></label>
                            </div>
                            <div class="col-md-12">
                                <label class="form-label" id="lblestatus"></label>
                            </div>
                        </div>
			        </div>
                    <div class="col-md-4">
                        <div class="row">
                            <div class="col-md-12" style="margin-top:15px;">             
				                <label class="form-label"><span id="fecha"></span></label>
                            </div>
                            <div class="col-md-12">
                                <label class="form-label"><span id="monto"></span></label>
                            </div>
                        </div>
			        </div>
                </form>
	        </div>
        </div>
    </div>
</div>




<script type="text/javascript">

    var _fec;
    var _user;

    $(document).ready(function () {

        mtd_ValidateSession();
        _user = $('#idUser').val();

        mtd_LeeAperturas(_user, '7');

        $('#btnApertura').click(function () {
            var id = $('#codigo').val();
            var url = "Facturacion/frm_Facturas.aspx?id=" + id;
            AjaxLink(url);
        });
        
    });

    function mtd_LeeAperturas(user,  accion) {
            var a = {'user': user, 'accion': accion};
            params = JSON.stringify(a);

            $.ajax({
                type: "POST",
                url: "Facturacion/frm_Apertura.aspx/mtd_LeeAperturas",
                data: params,
                contentType: "application/json; charset=utf-8",
                dataType: "json",
                async: true,
                success: function (msg) {
                    var mensaje = msg.d.split("||");

                    if (mensaje[0] == "OK") {
                        $('#codigo').val(mensaje[1]);
                        $('#lblfecha').val(mensaje[2]);
                        $('#lblestatus').val(mensaje[3]);
                        $('#fecha').val(mensaje[4]);
                        $('#monto').val(mensaje[5]);
                        $('#btnApertura').text(mensaje[6]);
                        
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


