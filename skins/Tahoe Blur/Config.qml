import QtQuick

// Skin "Tahoe Blur": mismo comportamiento y geometría que "Tahoe Dark" pero SIN
// imagen de fondo. El fondo (bg.png) es completamente transparente, de modo que
// lo único que se ve es el blur nativo de KWin detrás del dock. La región del
// blur la genera dockBackground a partir de sus anchors/márgenes, así que se
// adapta sola al tamaño del dock, al número de iconos y al zoom, igual que en
// cualquier otro skin. blurRadius controla el redondeo de las esquinas del blur.
QtObject {
    property string imageTop: "bg.png"
    property string imageBottom: "bg.png"
    property string imageLeft: "bg.png"
    property string imageRight: "bg.png"
    property string imagetask: "tasks.svgz"
    property bool blur: true
    property int blurRadius: 32

    // Marco vectorial estilo macOS (sin imagen): filo claro fino + un tinte
    // interior muy sutil sobre el blur. El radio se hereda de blurRadius, así
    // que el filo sigue exactamente el borde de la región difuminada.
    property bool frame: true
    property color frameColor: "#30ffffff"   // ~19% blanco: filo claro sutil
    property color frameFill: "#1fffffff"    // ~12% blanco: panel translúcido
    property int frameBorder: 1

    property int positionTaskIndicator: 9
    property int leftMargin: 20
    property int topMargin: 20
    property int rightMargin: 20
    property int bottomMargin: 20
    property int outsideLeftMargin: 16
    property int outsideTopMargin: 16
    property int outsideRightMargin: 16
    property int outsideBottomMargin: -4
}
