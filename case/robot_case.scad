// Boitier parametrique pour le robot IA (ESP32-S3 + ecran 1,3" + micro + HP).
// OpenSCAD. Change "part" : "front", "back" ou "both" (apercu). Exporte chaque piece en STL.
// ATTENTION : les cotes des composants ci-dessous sont des ESTIMATIONS.
// Mesure tes pieces au pied a coulisse et corrige les parametres avant d'imprimer.

part = "both";          // "front" | "back" | "both"

// ---- Cotes des composants (mm) : A MESURER ----
lcd_pcb_w   = 33;       // largeur du PCB de l'ecran
lcd_pcb_h   = 35;       // hauteur du PCB de l'ecran
lcd_pcb_t   = 3.5;      // epaisseur PCB + dalle (sans connecteur)
lcd_win_w   = 24;       // fenetre visible (zone active)
lcd_win_h   = 24;
lcd_win_dy  = 0;        // decalage vertical de la fenetre / centre du PCB

spk_d       = 28;       // diametre du haut-parleur
spk_h       = 5;        // epaisseur du haut-parleur

mic_hole_d  = 2.5;      // trou d'acces du micro INMP441

esp_l       = 70;       // longueur de la carte ESP32-S3 DevKitC-1
esp_w       = 26;       // largeur
esp_h       = 14;       // hauteur avec barrettes de broches (sans fils)
usb_w       = 10;       // ouverture USB-C
usb_h       = 4;

// ---- Parametres du boitier ----
wall   = 2.4;           // epaisseur des parois
tol    = 0.4;           // jeu d'ajustement
corner = 6;             // rayon des coins
out_w  = 84;            // largeur exterieure
out_h  = 80;            // hauteur exterieure
out_d  = 44;            // profondeur exterieure totale
front_d = 24;           // profondeur de la coque avant (le reste = couvercle arriere)
screw_d = 2.2;          // trou de vis M2.5 (taraudage direct dans le plastique)
screw_post = 6;         // diametre des plots de vis
$fn = 48;

module rrect(w, h, d, r) {
    translate([-w/2 + r, -h/2 + r, 0])
        hull() for (x = [0, w - 2*r], y = [0, h - 2*r])
            translate([x, y, 0]) cylinder(r = r, h = d);
}

// positions des 4 plots de vis (dans les coins interieurs)
function posts() = [
    [ out_w/2 - wall - 4,  out_h/2 - wall - 4],
    [-out_w/2 + wall + 4,  out_h/2 - wall - 4],
    [ out_w/2 - wall - 4, -out_h/2 + wall + 4],
    [-out_w/2 + wall + 4, -out_h/2 + wall + 4]
];

module front_shell() {
    difference() {
        rrect(out_w, out_h, front_d, corner);
        // cavite interieure (ouverte vers l'arriere)
        translate([0, 0, wall]) rrect(out_w - 2*wall, out_h - 2*wall, front_d, corner - wall/2);
        // fenetre de l'ecran
        translate([-lcd_win_w/2, -lcd_win_h/2 + lcd_win_dy + 8, -1])
            cube([lcd_win_w, lcd_win_h, wall + 2]);
        // trou du micro (au-dessus de l'ecran)
        translate([0, out_h/2 - 8, -1]) cylinder(d = mic_hole_d, h = wall + 2);
        // trous de vis dans les plots
        for (p = posts()) translate([p[0], p[1], wall]) cylinder(d = screw_d, h = front_d);
    }
    // logement de l'ecran : cadre qui maintient le PCB contre la face avant
    difference() {
        translate([-(lcd_pcb_w + 2*wall)/2, -(lcd_pcb_h + 2*wall)/2 + 8, wall])
            cube([lcd_pcb_w + 2*wall, lcd_pcb_h + 2*wall, lcd_pcb_t + 1.5]);
        translate([-(lcd_pcb_w + tol)/2, -(lcd_pcb_h + tol)/2 + 8, wall - 0.01])
            cube([lcd_pcb_w + tol, lcd_pcb_h + tol, lcd_pcb_t + 2]);
        // la fenetre reste percee
        translate([-lcd_win_w/2, -lcd_win_h/2 + lcd_win_dy + 8, -1])
            cube([lcd_win_w, lcd_win_h, wall + 5]);
    }
    // plots de vis
    for (p = posts())
        difference() {
            translate([p[0], p[1], wall]) cylinder(d = screw_post, h = front_d - wall);
            translate([p[0], p[1], wall]) cylinder(d = screw_d, h = front_d);
        }
}

module back_cover() {
    back_d = out_d - front_d;
    difference() {
        rrect(out_w, out_h, back_d, corner);
        translate([0, 0, wall]) rrect(out_w - 2*wall, out_h - 2*wall, back_d, corner - wall/2);
        // ouverture USB-C (bas du couvercle, centree)
        translate([-usb_w/2, -out_h/2 - 1, back_d/2 - usb_h/2 + wall/2])
            cube([usb_w, wall + 2, usb_h]);
        // grille du haut-parleur au dos (anneaux de trous)
        translate([0, 12, -1]) {
            for (a = [0 : 45 : 315]) rotate(a) translate([spk_d/4, 0, 0]) cylinder(d = 2.2, h = wall + 2);
            for (a = [0 : 30 : 330]) rotate(a) translate([spk_d/2 - 3.5, 0, 0]) cylinder(d = 2.2, h = wall + 2);
            cylinder(d = 2.2, h = wall + 2);
        }
        // trous de vis (passage)
        for (p = posts()) translate([p[0], p[1], -1]) cylinder(d = 2.8, h = wall + 2);
    }
    // anneau de maintien du haut-parleur
    translate([0, 12, wall]) difference() {
        cylinder(d = spk_d + 2*wall + tol, h = min(spk_h + 1, back_d - wall));
        translate([0, 0, -0.01]) cylinder(d = spk_d + tol, h = back_d);
    }
}

if (part == "front") front_shell();
if (part == "back")  back_cover();
if (part == "both") {
    front_shell();
    translate([out_w + 10, 0, 0]) back_cover();
}
