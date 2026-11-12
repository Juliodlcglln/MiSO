// PJD Shell - layout de escritorio moderno para KDE Plasma 6 (WanukuOS)
// Se aplica a usuarios nuevos mediante el look-and-feel org.miso.pjd.desktop.

var plasma = getApiVersion(1);

// Panel inferior moderno estilo Dock flotante
var panel = new Panel("org.kde.panel");
panel.location = "bottom";
panel.height = Math.round(gridUnit * 2.6); // ~46px para diseño táctil y de escritorio moderno
panel.floating = true; // Activa esquinas redondeadas y panel flotante moderno en Plasma 6

// Lanzador de aplicaciones principal
var kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "wanuku-logo");

// Barra de tareas con iconos de aplicaciones ancladas modernas
var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox-esr.desktop",
    "applications:libreoffice-writer.desktop",
    "applications:libreoffice-calc.desktop",
    "applications:org.kde.elisa.desktop",
    "applications:vlc.desktop",
    "applications:org.kde.kcalc.desktop",
    "applications:org.kde.plasma-systemmonitor.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:wanuku-install.desktop"
]);

// Separador y bandeja del sistema
panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");

// Reloj digital estilizado
panel.addWidget("org.kde.plasma.digitalclock");

// Escritorios: fondo WanukuOS e iconos de ~/Desktop
var desktops = desktops();
for (var i = 0; i < desktops.length; i++) {
    var d = desktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/wanuku-default.png");

    // Folder View: muestra ~/Desktop (incluye "Instalar WanukuOS").
    d.addWidget("org.kde.plasma.folder");
}
