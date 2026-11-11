// PJD Shell - layout de escritorio para KDE Plasma 6
// Se aplica a usuarios nuevos mediante el look-and-feel org.miso.pjd.desktop.

var plasma = getApiVersion(1);

// Panel inferior
var panel = new Panel("org.kde.panel");
panel.location = "bottom";
panel.height = Math.round(gridUnit * 2.5);

// Lanzador
var kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "start-here-miso");

// Tareas
panel.addWidget("org.kde.plasma.icontasks");

// Separador y bandeja
panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");

// Reloj
panel.addWidget("org.kde.plasma.digitalclock");

// Escritorios: fondo MiSO e iconos de ~/Desktop
var desktops = desktops();
for (var i = 0; i < desktops.length; i++) {
    var d = desktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/miso-default.png");

    // Folder View: muestra ~/Desktop (incluye "Instalar MiSO Desktop").
    d.addWidget("org.kde.plasma.folder");
}
