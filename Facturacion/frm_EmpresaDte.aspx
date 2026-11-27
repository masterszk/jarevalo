<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="frm_EmpresaDte.aspx.cs" Inherits="DPieCenter.Facturacion.frm_EmpresaDte" %>

<%-- Los datos del emisor de los DTE ahora están en Opciones > Datos de la empresa (pestaña Facturación electrónica) --%>
<div class="text-center text-muted py-5"><div class="spinner-border spinner-border-sm text-primary"></div> Abriendo datos de la empresa…</div>
<script>AjaxLink('Opciones/form_confEmpresa.aspx?tab=dte', { historial: 'reemplazar' });</script>
