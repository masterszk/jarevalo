<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confUsuarioPerfilEdit.aspx.cs" Inherits="DPieCenter.Perfiles.form_confUsuarioPerfilEdit" %>

<%-- Los usuarios ahora se crean y editan en un modal de form_confUsuarios.aspx --%>
<div class="text-center text-muted py-5"><div class="spinner-border spinner-border-sm text-primary"></div> Abriendo usuarios…</div>
<script>AjaxLink('Perfiles/form_confUsuarios.aspx?user=<%= HttpUtility.JavaScriptStringEncode(HttpUtility.UrlEncode(Request.QueryString["user"] ?? "")) %>', { historial: 'reemplazar' });</script>
