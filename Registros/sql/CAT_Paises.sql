/* =====================================================================
   DPieCenter - Nacionalidad del paciente y formato de teléfono y documento por país
   (Registros/frm_ListaExpedientes.aspx y frm_EditExpediente.aspx)

   CAT_PAISES: países del mundo con el código telefónico internacional, la cantidad de dígitos del número nacional
   y el formato (máscara) del teléfono y del documento de identidad del país.
   Máscaras: # = dígito, A = letra, * = letra o dígito; cualquier otro carácter se escribe tal cual.
   EXP_EXPEDIENTES:
     - Id_Pais_FK: nacionalidad (los existentes quedan como El Salvador).
     - Id_PaisTelefono_FK: país de los teléfonos (código +503, etc.). Los números se guardan solo con dígitos.
   CAT_TIPOSDOCUMENTOS 5: documento de identidad de otro país (DTE: CAT-022 "37 Otro").
   Script idempotente: se puede ejecutar varias veces.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.CAT_PAISES', 'U') IS NULL
    CREATE TABLE dbo.CAT_PAISES (
        Id_Pais           int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CAT_PAISES PRIMARY KEY,
        Iso2              char(2)      NOT NULL CONSTRAINT UX_CAT_PAISES_Iso2 UNIQUE,
        Nombre            varchar(80)  NOT NULL,
        CodigoTelefono    varchar(6)   NOT NULL,      -- sin "+"
        TelefonoMin       tinyint      NOT NULL CONSTRAINT DF_CAT_PAISES_TelMin DEFAULT (6),
        TelefonoMax       tinyint      NOT NULL CONSTRAINT DF_CAT_PAISES_TelMax DEFAULT (15),
        MascaraTelefono   varchar(30)  NULL,
        DocumentoNombre   varchar(60)  NULL,          -- documento de identidad del país (DUI, DPI, DNI...)
        MascaraDocumento  varchar(30)  NULL,
        Orden             int          NOT NULL CONSTRAINT DF_CAT_PAISES_Orden DEFAULT (100),
        Activo            bit          NOT NULL CONSTRAINT DF_CAT_PAISES_Activo DEFAULT (1)
    );
GO

/* Carga / actualización del catálogo */
DECLARE @p TABLE (Iso2 char(2), Nombre varchar(80), Codigo varchar(6), Mn tinyint, Mx tinyint, MTel varchar(30), Doc varchar(60), MDoc varchar(30), Orden int);
INSERT INTO @p VALUES
 ('SV','El Salvador','503',8,8,'####-####','DUI','########-#',1)
,('GT','Guatemala','502',8,8,'####-####','DPI','#### ##### ####',2)
,('HN','Honduras','504',8,8,'####-####','DNI','####-####-#####',3)
,('NI','Nicaragua','505',8,8,'####-####','Cédula de identidad','###-######-####A',4)
,('CR','Costa Rica','506',8,8,'####-####','Cédula de identidad','#-####-####',5)
,('PA','Panamá','507',7,8,'####-####','Cédula de identidad',NULL,6)
,('BZ','Belice','501',7,7,'###-####',NULL,NULL,7)
,('MX','México','52',10,10,'## #### ####','CURP','AAAA######AAAAAA**',8)
,('US','Estados Unidos','1',10,10,'(###) ###-####','ID / Licencia',NULL,9)
,('AF','Afganistán','93',9,9,NULL,NULL,NULL,100)
,('AL','Albania','355',8,9,NULL,NULL,NULL,100)
,('DE','Alemania','49',10,11,NULL,'Personalausweis',NULL,100)
,('AD','Andorra','376',6,9,NULL,NULL,NULL,100)
,('AO','Angola','244',9,9,'### ### ###',NULL,NULL,100)
,('AG','Antigua y Barbuda','1',10,10,'(###) ###-####',NULL,NULL,100)
,('SA','Arabia Saudita','966',9,9,NULL,NULL,NULL,100)
,('DZ','Argelia','213',9,9,NULL,NULL,NULL,100)
,('AR','Argentina','54',10,10,'## ####-####','DNI','########',100)
,('AM','Armenia','374',8,8,NULL,NULL,NULL,100)
,('AW','Aruba','297',7,7,'### ####',NULL,NULL,100)
,('AU','Australia','61',9,9,'### ### ###',NULL,NULL,100)
,('AT','Austria','43',10,13,NULL,NULL,NULL,100)
,('AZ','Azerbaiyán','994',9,9,NULL,NULL,NULL,100)
,('BS','Bahamas','1',10,10,'(###) ###-####',NULL,NULL,100)
,('BD','Bangladés','880',10,10,NULL,NULL,NULL,100)
,('BB','Barbados','1',10,10,'(###) ###-####',NULL,NULL,100)
,('BH','Baréin','973',8,8,NULL,NULL,NULL,100)
,('BE','Bélgica','32',9,9,'### ## ## ##',NULL,NULL,100)
,('BJ','Benín','229',8,10,NULL,NULL,NULL,100)
,('BY','Bielorrusia','375',9,9,NULL,NULL,NULL,100)
,('MM','Birmania (Myanmar)','95',8,10,NULL,NULL,NULL,100)
,('BO','Bolivia','591',8,8,'#### ####','Cédula de identidad',NULL,100)
,('BA','Bosnia y Herzegovina','387',8,9,NULL,NULL,NULL,100)
,('BW','Botsuana','267',7,8,NULL,NULL,NULL,100)
,('BR','Brasil','55',10,11,'(##) #####-####','CPF','###.###.###-##',100)
,('BN','Brunéi','673',7,7,NULL,NULL,NULL,100)
,('BG','Bulgaria','359',8,9,NULL,NULL,NULL,100)
,('BF','Burkina Faso','226',8,8,NULL,NULL,NULL,100)
,('BI','Burundi','257',8,8,NULL,NULL,NULL,100)
,('BT','Bután','975',7,8,NULL,NULL,NULL,100)
,('CV','Cabo Verde','238',7,7,NULL,NULL,NULL,100)
,('KH','Camboya','855',8,9,NULL,NULL,NULL,100)
,('CM','Camerún','237',9,9,NULL,NULL,NULL,100)
,('CA','Canadá','1',10,10,'(###) ###-####',NULL,NULL,100)
,('QA','Catar','974',8,8,NULL,NULL,NULL,100)
,('TD','Chad','235',8,8,NULL,NULL,NULL,100)
,('CL','Chile','56',9,9,'# #### ####','RUT','##.###.###-*',100)
,('CN','China','86',11,11,'### #### ####',NULL,NULL,100)
,('CY','Chipre','357',8,8,NULL,NULL,NULL,100)
,('VA','Ciudad del Vaticano','39',6,11,NULL,NULL,NULL,100)
,('CO','Colombia','57',10,10,'### ### ####','Cédula de ciudadanía',NULL,100)
,('KM','Comoras','269',7,7,NULL,NULL,NULL,100)
,('CG','Congo','242',9,9,NULL,NULL,NULL,100)
,('CD','Congo (Rep. Democrática)','243',9,9,NULL,NULL,NULL,100)
,('KP','Corea del Norte','850',8,10,NULL,NULL,NULL,100)
,('KR','Corea del Sur','82',9,10,'##-####-####',NULL,NULL,100)
,('CI','Costa de Marfil','225',10,10,NULL,NULL,NULL,100)
,('HR','Croacia','385',8,9,NULL,NULL,NULL,100)
,('CU','Cuba','53',8,8,'# ### ####','Carné de identidad',NULL,100)
,('CW','Curazao','599',7,8,NULL,NULL,NULL,100)
,('DK','Dinamarca','45',8,8,'## ## ## ##',NULL,NULL,100)
,('DM','Dominica','1',10,10,'(###) ###-####',NULL,NULL,100)
,('EC','Ecuador','593',9,9,'## ### ####','Cédula de identidad','##########',100)
,('EG','Egipto','20',10,10,NULL,NULL,NULL,100)
,('AE','Emiratos Árabes Unidos','971',9,9,NULL,NULL,NULL,100)
,('ER','Eritrea','291',7,7,NULL,NULL,NULL,100)
,('SK','Eslovaquia','421',9,9,NULL,NULL,NULL,100)
,('SI','Eslovenia','386',8,8,NULL,NULL,NULL,100)
,('ES','España','34',9,9,'### ### ###','DNI / NIE','*#######A',100)
,('EE','Estonia','372',7,8,NULL,NULL,NULL,100)
,('SZ','Esuatini','268',8,8,NULL,NULL,NULL,100)
,('ET','Etiopía','251',9,9,NULL,NULL,NULL,100)
,('PH','Filipinas','63',10,10,NULL,NULL,NULL,100)
,('FI','Finlandia','358',9,10,NULL,NULL,NULL,100)
,('FJ','Fiyi','679',7,7,NULL,NULL,NULL,100)
,('FR','Francia','33',9,9,'# ## ## ## ##',NULL,NULL,100)
,('GA','Gabón','241',7,8,NULL,NULL,NULL,100)
,('GM','Gambia','220',7,7,NULL,NULL,NULL,100)
,('GE','Georgia','995',9,9,NULL,NULL,NULL,100)
,('GH','Ghana','233',9,9,NULL,NULL,NULL,100)
,('GD','Granada','1',10,10,'(###) ###-####',NULL,NULL,100)
,('GR','Grecia','30',10,10,NULL,NULL,NULL,100)
,('GN','Guinea','224',9,9,NULL,NULL,NULL,100)
,('GQ','Guinea Ecuatorial','240',9,9,NULL,NULL,NULL,100)
,('GW','Guinea-Bisáu','245',7,9,NULL,NULL,NULL,100)
,('GY','Guyana','592',7,7,NULL,NULL,NULL,100)
,('HT','Haití','509',8,8,'## ## ####',NULL,NULL,100)
,('HK','Hong Kong','852',8,8,'#### ####',NULL,NULL,100)
,('HU','Hungría','36',8,9,NULL,NULL,NULL,100)
,('IN','India','91',10,10,'##### #####',NULL,NULL,100)
,('ID','Indonesia','62',9,12,NULL,NULL,NULL,100)
,('IQ','Irak','964',10,10,NULL,NULL,NULL,100)
,('IR','Irán','98',10,10,NULL,NULL,NULL,100)
,('IE','Irlanda','353',9,9,NULL,NULL,NULL,100)
,('IS','Islandia','354',7,7,NULL,NULL,NULL,100)
,('MH','Islas Marshall','692',7,7,NULL,NULL,NULL,100)
,('SB','Islas Salomón','677',7,7,NULL,NULL,NULL,100)
,('IL','Israel','972',9,9,NULL,NULL,NULL,100)
,('IT','Italia','39',9,10,NULL,NULL,NULL,100)
,('JM','Jamaica','1',10,10,'(###) ###-####',NULL,NULL,100)
,('JP','Japón','81',10,10,'##-####-####',NULL,NULL,100)
,('JO','Jordania','962',9,9,NULL,NULL,NULL,100)
,('KZ','Kazajistán','7',10,10,NULL,NULL,NULL,100)
,('KE','Kenia','254',9,9,NULL,NULL,NULL,100)
,('KG','Kirguistán','996',9,9,NULL,NULL,NULL,100)
,('KI','Kiribati','686',8,8,NULL,NULL,NULL,100)
,('XK','Kosovo','383',8,9,NULL,NULL,NULL,100)
,('KW','Kuwait','965',8,8,NULL,NULL,NULL,100)
,('LA','Laos','856',8,10,NULL,NULL,NULL,100)
,('LS','Lesoto','266',8,8,NULL,NULL,NULL,100)
,('LV','Letonia','371',8,8,NULL,NULL,NULL,100)
,('LB','Líbano','961',7,8,NULL,NULL,NULL,100)
,('LR','Liberia','231',7,9,NULL,NULL,NULL,100)
,('LY','Libia','218',9,9,NULL,NULL,NULL,100)
,('LI','Liechtenstein','423',7,9,NULL,NULL,NULL,100)
,('LT','Lituania','370',8,8,NULL,NULL,NULL,100)
,('LU','Luxemburgo','352',6,11,NULL,NULL,NULL,100)
,('MO','Macao','853',8,8,NULL,NULL,NULL,100)
,('MK','Macedonia del Norte','389',8,8,NULL,NULL,NULL,100)
,('MG','Madagascar','261',9,9,NULL,NULL,NULL,100)
,('MY','Malasia','60',9,10,NULL,NULL,NULL,100)
,('MW','Malaui','265',7,9,NULL,NULL,NULL,100)
,('MV','Maldivas','960',7,7,NULL,NULL,NULL,100)
,('ML','Malí','223',8,8,NULL,NULL,NULL,100)
,('MT','Malta','356',8,8,NULL,NULL,NULL,100)
,('MA','Marruecos','212',9,9,NULL,NULL,NULL,100)
,('MU','Mauricio','230',7,8,NULL,NULL,NULL,100)
,('MR','Mauritania','222',8,8,NULL,NULL,NULL,100)
,('FM','Micronesia','691',7,7,NULL,NULL,NULL,100)
,('MD','Moldavia','373',8,8,NULL,NULL,NULL,100)
,('MC','Mónaco','377',8,9,NULL,NULL,NULL,100)
,('MN','Mongolia','976',8,8,NULL,NULL,NULL,100)
,('ME','Montenegro','382',8,8,NULL,NULL,NULL,100)
,('MZ','Mozambique','258',9,9,NULL,NULL,NULL,100)
,('NA','Namibia','264',9,9,NULL,NULL,NULL,100)
,('NR','Nauru','674',7,7,NULL,NULL,NULL,100)
,('NP','Nepal','977',10,10,NULL,NULL,NULL,100)
,('NE','Níger','227',8,8,NULL,NULL,NULL,100)
,('NG','Nigeria','234',10,10,NULL,NULL,NULL,100)
,('NO','Noruega','47',8,8,'### ## ###',NULL,NULL,100)
,('NZ','Nueva Zelanda','64',8,10,NULL,NULL,NULL,100)
,('OM','Omán','968',8,8,NULL,NULL,NULL,100)
,('NL','Países Bajos','31',9,9,'# ########',NULL,NULL,100)
,('PK','Pakistán','92',10,10,NULL,NULL,NULL,100)
,('PW','Palaos','680',7,7,NULL,NULL,NULL,100)
,('PS','Palestina','970',9,9,NULL,NULL,NULL,100)
,('PG','Papúa Nueva Guinea','675',8,8,NULL,NULL,NULL,100)
,('PY','Paraguay','595',9,9,'### ### ###','Cédula de identidad',NULL,100)
,('PE','Perú','51',9,9,'### ### ###','DNI','########',100)
,('PL','Polonia','48',9,9,'### ### ###',NULL,NULL,100)
,('PT','Portugal','351',9,9,'### ### ###',NULL,NULL,100)
,('PR','Puerto Rico','1',10,10,'(###) ###-####',NULL,NULL,100)
,('GB','Reino Unido','44',10,10,'#### ######',NULL,NULL,100)
,('CF','República Centroafricana','236',8,8,NULL,NULL,NULL,100)
,('CZ','República Checa','420',9,9,'### ### ###',NULL,NULL,100)
,('DO','República Dominicana','1',10,10,'(###) ###-####','Cédula de identidad','###-#######-#',100)
,('RW','Ruanda','250',9,9,NULL,NULL,NULL,100)
,('RO','Rumania','40',9,9,NULL,NULL,NULL,100)
,('RU','Rusia','7',10,10,'### ###-##-##',NULL,NULL,100)
,('WS','Samoa','685',5,7,NULL,NULL,NULL,100)
,('KN','San Cristóbal y Nieves','1',10,10,'(###) ###-####',NULL,NULL,100)
,('SM','San Marino','378',6,10,NULL,NULL,NULL,100)
,('VC','San Vicente y las Granadinas','1',10,10,'(###) ###-####',NULL,NULL,100)
,('LC','Santa Lucía','1',10,10,'(###) ###-####',NULL,NULL,100)
,('ST','Santo Tomé y Príncipe','239',7,7,NULL,NULL,NULL,100)
,('SN','Senegal','221',9,9,NULL,NULL,NULL,100)
,('RS','Serbia','381',8,9,NULL,NULL,NULL,100)
,('SC','Seychelles','248',7,7,NULL,NULL,NULL,100)
,('SL','Sierra Leona','232',8,8,NULL,NULL,NULL,100)
,('SG','Singapur','65',8,8,'#### ####',NULL,NULL,100)
,('SY','Siria','963',9,9,NULL,NULL,NULL,100)
,('SO','Somalia','252',7,9,NULL,NULL,NULL,100)
,('LK','Sri Lanka','94',9,9,NULL,NULL,NULL,100)
,('ZA','Sudáfrica','27',9,9,'## ### ####',NULL,NULL,100)
,('SD','Sudán','249',9,9,NULL,NULL,NULL,100)
,('SS','Sudán del Sur','211',9,9,NULL,NULL,NULL,100)
,('SE','Suecia','46',7,10,NULL,NULL,NULL,100)
,('CH','Suiza','41',9,9,'## ### ## ##',NULL,NULL,100)
,('SR','Surinam','597',6,7,NULL,NULL,NULL,100)
,('TH','Tailandia','66',9,9,NULL,NULL,NULL,100)
,('TW','Taiwán','886',9,9,NULL,NULL,NULL,100)
,('TZ','Tanzania','255',9,9,NULL,NULL,NULL,100)
,('TJ','Tayikistán','992',9,9,NULL,NULL,NULL,100)
,('TL','Timor Oriental','670',7,8,NULL,NULL,NULL,100)
,('TG','Togo','228',8,8,NULL,NULL,NULL,100)
,('TO','Tonga','676',5,7,NULL,NULL,NULL,100)
,('TT','Trinidad y Tobago','1',10,10,'(###) ###-####',NULL,NULL,100)
,('TN','Túnez','216',8,8,NULL,NULL,NULL,100)
,('TM','Turkmenistán','993',8,8,NULL,NULL,NULL,100)
,('TR','Turquía','90',10,10,'### ### ## ##',NULL,NULL,100)
,('TV','Tuvalu','688',5,7,NULL,NULL,NULL,100)
,('UA','Ucrania','380',9,9,NULL,NULL,NULL,100)
,('UG','Uganda','256',9,9,NULL,NULL,NULL,100)
,('UY','Uruguay','598',8,8,'#### ####','Cédula de identidad','#.###.###-#',100)
,('UZ','Uzbekistán','998',9,9,NULL,NULL,NULL,100)
,('VU','Vanuatu','678',7,7,NULL,NULL,NULL,100)
,('VE','Venezuela','58',10,10,'### ###-####','Cédula de identidad',NULL,100)
,('VN','Vietnam','84',9,10,NULL,NULL,NULL,100)
,('YE','Yemen','967',9,9,NULL,NULL,NULL,100)
,('DJ','Yibuti','253',8,8,NULL,NULL,NULL,100)
,('ZM','Zambia','260',9,9,NULL,NULL,NULL,100)
,('ZW','Zimbabue','263',9,9,NULL,NULL,NULL,100);

MERGE dbo.CAT_PAISES AS t
USING @p AS s ON t.Iso2 = s.Iso2
WHEN MATCHED THEN UPDATE SET Nombre = s.Nombre, CodigoTelefono = s.Codigo, TelefonoMin = s.Mn, TelefonoMax = s.Mx,
    MascaraTelefono = s.MTel, DocumentoNombre = s.Doc, MascaraDocumento = s.MDoc, Orden = s.Orden
WHEN NOT MATCHED THEN INSERT (Iso2, Nombre, CodigoTelefono, TelefonoMin, TelefonoMax, MascaraTelefono, DocumentoNombre, MascaraDocumento, Orden)
    VALUES (s.Iso2, s.Nombre, s.Codigo, s.Mn, s.Mx, s.MTel, s.Doc, s.MDoc, s.Orden);
GO

/* ---------- Expedientes: nacionalidad y país de los teléfonos ---------- */
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Id_Pais_FK') IS NULL
    ALTER TABLE dbo.EXP_EXPEDIENTES ADD Id_Pais_FK int NULL CONSTRAINT FK_EXP_EXPEDIENTES_Pais REFERENCES dbo.CAT_PAISES (Id_Pais);
GO
IF COL_LENGTH('dbo.EXP_EXPEDIENTES', 'Id_PaisTelefono_FK') IS NULL
    ALTER TABLE dbo.EXP_EXPEDIENTES ADD Id_PaisTelefono_FK int NULL CONSTRAINT FK_EXP_EXPEDIENTES_PaisTel REFERENCES dbo.CAT_PAISES (Id_Pais);
GO
-- Los expedientes existentes son de El Salvador
DECLARE @sv int = (SELECT Id_Pais FROM dbo.CAT_PAISES WHERE Iso2 = 'SV');
UPDATE dbo.EXP_EXPEDIENTES SET Id_Pais_FK = @sv WHERE Id_Pais_FK IS NULL;
UPDATE dbo.EXP_EXPEDIENTES SET Id_PaisTelefono_FK = @sv WHERE Id_PaisTelefono_FK IS NULL;
GO
-- Los números internacionales tienen hasta 15 dígitos (se guardan sin código de país, solo dígitos)
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_EXPEDIENTES') AND name = 'Celular' AND max_length < 20)
    ALTER TABLE dbo.EXP_EXPEDIENTES ALTER COLUMN Celular varchar(20) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_EXPEDIENTES') AND name = 'Telefono' AND max_length < 20)
    ALTER TABLE dbo.EXP_EXPEDIENTES ALTER COLUMN Telefono varchar(20) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EXP_EXPEDIENTES') AND name = 'TelefonoEmergencia' AND max_length < 20)
    ALTER TABLE dbo.EXP_EXPEDIENTES ALTER COLUMN TelefonoEmergencia varchar(20) NULL;
GO

/* ---------- Tipo de documento para extranjeros ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.CAT_TIPOSDOCUMENTOS WHERE Id_TipoDocumento = 5)
BEGIN
    SET IDENTITY_INSERT dbo.CAT_TIPOSDOCUMENTOS ON;
    INSERT INTO dbo.CAT_TIPOSDOCUMENTOS (Id_TipoDocumento, Descripcion, Estatus, Digitos, Formato, UsuarioCrea, FechaCrea)
    VALUES (5, 'DOCUMENTO DE IDENTIDAD EXTRANJERO', 1, 0, 'X', 'admin', GETDATE());
    SET IDENTITY_INSERT dbo.CAT_TIPOSDOCUMENTOS OFF;
END
GO

/* Catálogo de países para los formularios */
CREATE OR ALTER PROCEDURE [dbo].[CAT_SP_Paises]
AS
BEGIN
    SET NOCOUNT ON;
    select Id_Pais, Iso2, Nombre, CodigoTelefono, TelefonoMin, TelefonoMax, MascaraTelefono, DocumentoNombre, MascaraDocumento
    from CAT_PAISES
    where Activo = 1
    order by Orden, Nombre
END
GO
