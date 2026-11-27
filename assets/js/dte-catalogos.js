/* Catálogos del Ministerio de Hacienda compartidos por las pantallas de DTE */
window.DteCatalogos = {
    // CAT-012 / CAT-013 (división territorial vigente desde 2024): [código, nombre, [[código municipio, nombre]]]
    departamentos: [
        ['01', 'Ahuachapán', [['13', 'Ahuachapán Norte'], ['14', 'Ahuachapán Centro'], ['15', 'Ahuachapán Sur']]],
        ['02', 'Santa Ana', [['14', 'Santa Ana Norte'], ['15', 'Santa Ana Centro'], ['16', 'Santa Ana Este'], ['17', 'Santa Ana Oeste']]],
        ['03', 'Sonsonate', [['17', 'Sonsonate Norte'], ['18', 'Sonsonate Centro'], ['19', 'Sonsonate Este'], ['20', 'Sonsonate Oeste']]],
        ['04', 'Chalatenango', [['34', 'Chalatenango Norte'], ['35', 'Chalatenango Centro'], ['36', 'Chalatenango Sur']]],
        ['05', 'La Libertad', [['23', 'La Libertad Norte'], ['24', 'La Libertad Centro'], ['25', 'La Libertad Oeste'], ['26', 'La Libertad Este'], ['27', 'La Libertad Costa'], ['28', 'La Libertad Sur']]],
        ['06', 'San Salvador', [['20', 'San Salvador Norte'], ['21', 'San Salvador Oeste'], ['22', 'San Salvador Este'], ['23', 'San Salvador Centro'], ['24', 'San Salvador Sur']]],
        ['07', 'Cuscatlán', [['17', 'Cuscatlán Norte'], ['18', 'Cuscatlán Sur']]],
        ['08', 'La Paz', [['23', 'La Paz Oeste'], ['24', 'La Paz Centro'], ['25', 'La Paz Este']]],
        ['09', 'Cabañas', [['10', 'Cabañas Oeste'], ['11', 'Cabañas Este']]],
        ['10', 'San Vicente', [['14', 'San Vicente Norte'], ['15', 'San Vicente Sur']]],
        ['11', 'Usulután', [['24', 'Usulután Norte'], ['25', 'Usulután Este'], ['26', 'Usulután Oeste']]],
        ['12', 'San Miguel', [['21', 'San Miguel Norte'], ['22', 'San Miguel Centro'], ['23', 'San Miguel Oeste']]],
        ['13', 'Morazán', [['27', 'Morazán Norte'], ['28', 'Morazán Sur']]],
        ['14', 'La Unión', [['19', 'La Unión Norte'], ['20', 'La Unión Sur']]]
    ],
    // CAT-009
    tiposEstablecimiento: [['01', 'Sucursal / Agencia'], ['02', 'Casa matriz'], ['04', 'Bodega'], ['07', 'Predio y/o patio'], ['20', 'Otro']],

    // DTE 2.0: distritos (antiguos municipios) por departamento: [código distrito, código municipio 2024, nombre]
    distritos: {
        '01': [['01', '14', 'Ahuachapán'], ['02', '14', 'Apaneca'], ['03', '13', 'Atiquizaya'], ['04', '14', 'Concepción de Ataco'], ['05', '13', 'El Refugio'], ['06', '15', 'Guaymango'],
               ['07', '15', 'Jujutla'], ['08', '15', 'San Francisco Menéndez'], ['09', '13', 'San Lorenzo'], ['10', '15', 'San Pedro Puxtla'], ['11', '14', 'Tacuba'], ['12', '13', 'Turín']],
        '02': [['01', '17', 'Candelaria de la Frontera'], ['02', '16', 'Coatepeque'], ['03', '17', 'Chalchuapa'], ['04', '16', 'El Congo'], ['05', '17', 'El Porvenir'], ['06', '14', 'Masahuat'],
               ['07', '14', 'Metapán'], ['08', '17', 'San Antonio Pajonal'], ['09', '17', 'San Sebastián Salitrillo'], ['10', '15', 'Santa Ana'], ['11', '14', 'Santa Rosa Guachipilín'],
               ['12', '17', 'Santiago de la Frontera'], ['13', '14', 'Texistepeque']],
        '03': [['01', '20', 'Acajutla'], ['02', '19', 'Armenia'], ['03', '19', 'Caluco'], ['04', '19', 'Cuisnahuat'], ['05', '19', 'Santa Isabel Ishuatán'], ['06', '19', 'Izalco'],
               ['07', '17', 'Juayúa'], ['08', '17', 'Nahuizalco'], ['09', '18', 'Nahulingo'], ['10', '17', 'Salcoatitán'], ['11', '18', 'San Antonio del Monte'], ['12', '19', 'San Julián'],
               ['13', '17', 'Santa Catarina Masahuat'], ['14', '18', 'Santo Domingo de Guzmán'], ['15', '18', 'Sonsonate'], ['16', '18', 'Sonzacate']],
        '04': [['01', '35', 'Agua Caliente'], ['02', '36', 'Arcatao'], ['03', '36', 'Azacualpa'], ['04', '34', 'Citalá'], ['05', '36', 'Comalapa'], ['06', '36', 'Concepción Quezaltepeque'],
               ['07', '36', 'Chalatenango'], ['08', '35', 'Dulce Nombre de María'], ['09', '36', 'El Carrizal'], ['10', '35', 'El Paraíso'], ['11', '36', 'La Laguna'], ['12', '34', 'La Palma'],
               ['13', '35', 'La Reina'], ['14', '36', 'Las Vueltas'], ['15', '36', 'Nombre de Jesús'], ['16', '35', 'Nueva Concepción'], ['17', '36', 'Nueva Trinidad'], ['18', '36', 'Ojos de Agua'],
               ['19', '36', 'Potonico'], ['20', '36', 'San Antonio de La Cruz'], ['21', '36', 'San Antonio Los Ranchos'], ['22', '35', 'San Fernando'], ['23', '36', 'San Francisco Lempa'],
               ['24', '35', 'San Francisco Morazán'], ['25', '34', 'San Ignacio'], ['26', '36', 'San Isidro Labrador'], ['27', '36', 'San José Cancasque'], ['28', '36', 'San José Las Flores'],
               ['29', '36', 'San Luis del Carmen'], ['30', '36', 'San Miguel de Mercedes'], ['31', '35', 'San Rafael'], ['32', '35', 'Santa Rita'], ['33', '35', 'Tejutla']],
        '05': [['01', '26', 'Antiguo Cuscatlán'], ['02', '24', 'Ciudad Arce'], ['03', '25', 'Colón'], ['04', '28', 'Comasagua'], ['05', '27', 'Chiltiupán'], ['06', '26', 'Huizúcar'],
               ['07', '25', 'Jayaque'], ['08', '27', 'Jicalapa'], ['09', '27', 'La Libertad'], ['10', '26', 'Nuevo Cuscatlán'], ['11', '28', 'Santa Tecla'], ['12', '23', 'Quezaltepeque'],
               ['13', '25', 'Sacacoyo'], ['14', '26', 'San José Villanueva'], ['15', '24', 'San Juan Opico'], ['16', '23', 'San Matías'], ['17', '23', 'San Pablo Tacachico'],
               ['18', '27', 'Tamanique'], ['19', '25', 'Talnique'], ['20', '27', 'Teotepeque'], ['21', '25', 'Tepecoyo'], ['22', '26', 'Zaragoza']],
        '06': [['01', '20', 'Aguilares'], ['02', '21', 'Apopa'], ['03', '23', 'Ayutuxtepeque'], ['04', '23', 'Cuscatancingo'], ['05', '20', 'El Paisnal'], ['06', '20', 'Guazapa'],
               ['07', '22', 'Ilopango'], ['08', '23', 'Mejicanos'], ['09', '21', 'Nejapa'], ['10', '24', 'Panchimalco'], ['11', '24', 'Rosario de Mora'], ['12', '24', 'San Marcos'],
               ['13', '22', 'San Martín'], ['14', '23', 'San Salvador'], ['15', '24', 'Santiago Texacuangos'], ['16', '24', 'Santo Tomás'], ['17', '22', 'Soyapango'],
               ['18', '22', 'Tonacatepeque'], ['19', '23', 'Ciudad Delgado']],
        '07': [['01', '18', 'Candelaria'], ['02', '18', 'Cojutepeque'], ['03', '18', 'El Carmen'], ['04', '18', 'El Rosario'], ['05', '18', 'Monte San Juan'], ['06', '17', 'Oratorio de Concepción'],
               ['07', '17', 'San Bartolomé Perulapía'], ['08', '18', 'San Cristóbal'], ['09', '17', 'San José Guayabal'], ['10', '17', 'San Pedro Perulapán'], ['11', '18', 'San Rafael Cedros'],
               ['12', '18', 'San Ramón'], ['13', '18', 'Santa Cruz Analquito'], ['14', '18', 'Santa Cruz Michapa'], ['15', '17', 'Suchitoto'], ['16', '18', 'Tenancingo']],
        '08': [['01', '23', 'Cuyultitán'], ['02', '24', 'El Rosario'], ['03', '24', 'Jerusalén'], ['04', '24', 'Mercedes La Ceiba'], ['05', '23', 'Olocuilta'], ['06', '24', 'Paraíso de Osorio'],
               ['07', '24', 'San Antonio Masahuat'], ['08', '24', 'San Emigdio'], ['09', '23', 'San Francisco Chinameca'], ['10', '25', 'San Juan Nonualco'], ['11', '23', 'San Juan Talpa'],
               ['12', '24', 'San Juan Tepezontes'], ['13', '23', 'San Luis Talpa'], ['14', '24', 'San Miguel Tepezontes'], ['15', '23', 'San Pedro Masahuat'], ['16', '24', 'San Pedro Nonualco'],
               ['17', '25', 'San Rafael Obrajuelo'], ['18', '24', 'Santa María Ostuma'], ['19', '24', 'Santiago Nonualco'], ['20', '23', 'Tapalhuaca'], ['21', '25', 'Zacatecoluca'],
               ['22', '24', 'San Luis La Herradura']],
        '09': [['01', '11', 'Cinquera'], ['02', '10', 'Guacotecti'], ['03', '11', 'Ilobasco'], ['04', '11', 'Jutiapa'], ['05', '10', 'San Isidro'], ['06', '10', 'Sensuntepeque'],
               ['07', '11', 'Tejutepeque'], ['08', '10', 'Victoria'], ['09', '10', 'Dolores']],
        '10': [['01', '14', 'Apastepeque'], ['02', '15', 'Guadalupe'], ['03', '15', 'San Cayetano Istepeque'], ['04', '14', 'Santa Clara'], ['05', '14', 'Santo Domingo'],
               ['06', '14', 'San Esteban Catarina'], ['07', '14', 'San Ildefonso'], ['08', '14', 'San Lorenzo'], ['09', '14', 'San Sebastián'], ['10', '15', 'San Vicente'],
               ['11', '15', 'Tecoluca'], ['12', '15', 'Tepetitán'], ['13', '15', 'Verapaz']],
        '11': [['01', '24', 'Alegría'], ['02', '24', 'Berlín'], ['03', '25', 'California'], ['04', '25', 'Concepción Batres'], ['05', '24', 'El Triunfo'], ['06', '25', 'Ereguayquín'],
               ['07', '24', 'Estanzuelas'], ['08', '26', 'Jiquilisco'], ['09', '24', 'Jucuapa'], ['10', '25', 'Jucuarán'], ['11', '24', 'Mercedes Umaña'], ['12', '24', 'Nueva Granada'],
               ['13', '25', 'Ozatlán'], ['14', '26', 'Puerto El Triunfo'], ['15', '26', 'San Agustín'], ['16', '24', 'San Buenaventura'], ['17', '25', 'San Dionisio'],
               ['18', '25', 'Santa Elena'], ['19', '26', 'San Francisco Javier'], ['20', '25', 'Santa María'], ['21', '24', 'Santiago de María'], ['22', '25', 'Tecapán'], ['23', '25', 'Usulután']],
        '12': [['01', '21', 'Carolina'], ['02', '21', 'Ciudad Barrios'], ['03', '22', 'Comacarán'], ['04', '21', 'Chapeltique'], ['05', '23', 'Chinameca'], ['06', '22', 'Chirilagua'],
               ['07', '23', 'El Tránsito'], ['08', '23', 'Lolotique'], ['09', '22', 'Moncagua'], ['10', '23', 'Nueva Guadalupe'], ['11', '21', 'Nuevo Edén de San Juan'], ['12', '22', 'Quelepa'],
               ['13', '21', 'San Antonio del Mosco'], ['14', '21', 'San Gerardo'], ['15', '23', 'San Jorge'], ['16', '21', 'San Luis de la Reina'], ['17', '22', 'San Miguel'],
               ['18', '23', 'San Rafael Oriente'], ['19', '21', 'Sesori'], ['20', '22', 'Uluazapa']],
        '13': [['01', '27', 'Arambala'], ['02', '27', 'Cacaopera'], ['03', '27', 'Corinto'], ['04', '28', 'Chilanga'], ['05', '28', 'Delicias de Concepción'], ['06', '28', 'El Divisadero'],
               ['07', '27', 'El Rosario'], ['08', '28', 'Gualococti'], ['09', '28', 'Guatajiagua'], ['10', '27', 'Joateca'], ['11', '27', 'Jocoaitique'], ['12', '28', 'Jocoro'],
               ['13', '28', 'Lolotiquillo'], ['14', '27', 'Meanguera'], ['15', '28', 'Osicala'], ['16', '27', 'Perquín'], ['17', '28', 'San Carlos'], ['18', '27', 'San Fernando'],
               ['19', '28', 'San Francisco Gotera'], ['20', '27', 'San Isidro'], ['21', '28', 'San Simón'], ['22', '28', 'Sensembra'], ['23', '28', 'Sociedad'], ['24', '27', 'Torola'],
               ['25', '28', 'Yamabal'], ['26', '28', 'Yoloaiquín']],
        '14': [['01', '19', 'Anamorós'], ['02', '19', 'Bolívar'], ['03', '19', 'Concepción de Oriente'], ['04', '20', 'Conchagua'], ['05', '20', 'El Carmen'], ['06', '19', 'El Sauce'],
               ['07', '20', 'Intipucá'], ['08', '20', 'La Unión'], ['09', '19', 'Lislique'], ['10', '20', 'Meanguera del Golfo'], ['11', '19', 'Nueva Esparta'], ['12', '19', 'Pasaquina'],
               ['13', '19', 'Polorós'], ['14', '20', 'San Alejo'], ['15', '19', 'San José La Fuente'], ['16', '19', 'Santa Rosa de Lima'], ['17', '20', 'Yayantique'], ['18', '20', 'Yucuaiquín']]
    },

    /** Distritos de un municipio 2024: [[código, nombre]] ordenados por nombre */
    distritosDe: function (depto, municipio) {
        return ((this.distritos[depto] || []).filter(function (d) { return d[1] === municipio; })
            .map(function (d) { return [d[0], d[2]]; })
            .sort(function (a, b) { return a[1].localeCompare(b[1], 'es'); }));
    }
};
