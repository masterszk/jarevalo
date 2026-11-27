<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="form_confNuevoUsuario.aspx.cs" Inherits="DPieCenter.Perfiles.form_confNuevoUsuario" %>

<%-- Los usuarios ahora se crean y editan en un modal de form_confUsuarios.aspx --%>
<div class="text-center text-muted py-5"><div class="spinner-border spinner-border-sm text-primary"></div> Abriendo usuarios…</div>
<script>AjaxLink('Perfiles/form_confUsuarios.aspx?nuevo=1', { historial: 'reemplazar' });</script>
