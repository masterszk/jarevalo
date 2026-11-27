<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confOpciones.aspx.cs" Inherits="DPieCenter.Opciones.form_confOpciones" %>

<%-- Las opciones ahora se administran junto a su módulo en form_confModulos.aspx --%>
<div class="text-center text-muted py-5"><div class="spinner-border spinner-border-sm text-primary"></div> Abriendo módulos y opciones…</div>
<script>AjaxLink('Opciones/form_confModulos.aspx?app=2&mod=<%= HttpUtility.JavaScriptStringEncode(Request.QueryString["mod"] ?? "") %>', { historial: 'reemplazar' });</script>
