// Boitier parametrique pour le robot IA (ESP32-S3 + ecran 1,3" + micro + HP).
// OpenSCAD. Change "part" : "front", "back" ou "both" (apercu). Exporte chaque piece en STL.
// ATTENTION : les cotes des composants ci-dessous sont des ESTIMATIONS.
// Mesure tes pieces au pied a coulisse et corrige les parametres avant d'imprimer.

part = "both";          // "front" | "back" | "both" | "assembled" | "section"

// ---- Cotes des composants (mm) : A MESURER ----
lcd_pcb_w   = 33;       // largeur du PCB de l'ecran
lcd_pcb_h   = 35;       // hauteur du PCB de l'ecran
lcd_pcb_t   = 3.5;      // epaisseur PCB + dalle (sans connecteur)
lcd_win_w   = 26;       // fenetre visible (zone active ~23,4 mm + petit jeu : ne pas trop agrandir)
lcd_win_h   = 26;
lcd_win_dy  = 0;        // decalage vertical de la fenetre / centre du PCB

spk_d       = 28;       // diametre du haut-parleur
spk_h       = 5;        // epaisseur du haut-parleur

mic_hole_d  = 2.5;      // trou d'acces du micro INMP441

esp_l       = 70;       // longueur de la carte ESP32-S3 DevKitC-1
esp_w       = 26;       // largeur
esp_h       = 14;       // hauteur avec barrettes de broches (sans fils)
usb_w       = 10;       // ouverture USB-C
usb_h       = 4;

batt_l      = 35;       // batterie LiPo plate (ex. 502535) : longueur
batt_w      = 25;       // largeur
batt_t      = 5;        // epaisseur (prevoir +1 mm si elle gonfle)
esp_x       = -15.5;    // carte ESP32 placee verticalement (USB vers le bas), a gauche
esp_y       = 0;
spk_x       = 15.5;     // haut-parleur a droite
spk_y       = 0;
screen_cy   = 15;       // centre vertical de l'ecran sur la face avant
esp_standoff = 3;       // hauteur des cales sous la carte

// ---- Parametres du boitier ----
wall   = 2.4;           // epaisseur des parois
tol    = 0.4;           // jeu d'ajustement
corner = 6;             // rayon des coins
out_w  = 68;            // largeur exterieure
out_h  = 78;            // hauteur exterieure
out_d  = 42;            // profondeur exterieure totale
front_d = 20;           // profondeur de la coque avant (le reste = couvercle arriere)
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

// Butees pour la batterie plate, a plat contre l'interieur de la face avant, sous l'ecran.
module battery_cradle() {
    by = -out_h/2 + wall + batt_w/2 + 0.5;   // collee en bas de la cavite
    L = batt_l + tol; W = batt_w + tol; h = batt_t + 2;
    for (sx = [-1, 1])
        translate([sx * (L/2 + 0.8) - 0.8, by - 5, wall - 0.01]) cube([1.6, 10, h]);
    translate([-8, by + W/2, wall - 0.01]) cube([16, 1.6, h]);
}

module front_shell() {
    difference() {
        rrect(out_w, out_h, front_d, corner);
        // cavite interieure (ouverte vers l'arriere)
        translate([0, 0, wall]) rrect(out_w - 2*wall, out_h - 2*wall, front_d, corner - wall/2);
        // fenetre de l'ecran
        translate([-lcd_win_w/2, -lcd_win_h/2 + lcd_win_dy + screen_cy, -1])
            cube([lcd_win_w, lcd_win_h, wall + 2]);
        // trou du micro (sous l'ecran)
        translate([0, screen_cy - lcd_pcb_h/2 - 6, -1]) cylinder(d = mic_hole_d, h = wall + 2);
        // trous de vis dans les plots
        for (p = posts()) translate([p[0], p[1], wall]) cylinder(d = screw_d, h = front_d);
    }
    // logement de l'ecran : cadre qui maintient le PCB contre la face avant
    difference() {
        translate([-(lcd_pcb_w + 2*wall)/2, -(lcd_pcb_h + 2*wall)/2 + screen_cy, wall])
            cube([lcd_pcb_w + 2*wall, lcd_pcb_h + 2*wall, lcd_pcb_t + 1.5]);
        translate([-(lcd_pcb_w + tol)/2, -(lcd_pcb_h + tol)/2 + screen_cy, wall - 0.01])
            cube([lcd_pcb_w + tol, lcd_pcb_h + tol, lcd_pcb_t + 2]);
        // la fenetre reste percee
        translate([-lcd_win_w/2, -lcd_win_h/2 + lcd_win_dy + screen_cy, -1])
            cube([lcd_win_w, lcd_win_h, wall + 5]);
    }
    battery_cradle();
    // plots de vis
    for (p = posts())
        difference() {
            translate([p[0], p[1], wall]) cylinder(d = screw_post, h = front_d - wall);
            translate([p[0], p[1], wall]) cylinder(d = screw_d, h = front_d);
        }
}

// Cales + butees qui maintiennent la carte ESP32, placee verticalement, USB vers le bas (-y).
// Un point de colle chaude reste conseille. Dessin en repere local (USB vers +x), puis rotation.
module esp_cradle() {
    L = esp_l + tol; W = esp_w + tol;
    h = esp_standoff + 5;
    translate([esp_x, esp_y, 0]) rotate(-90) {
        // 4 cales sous la carte (rentrees pour ne pas boucher les trous de vis du fond)
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * (L/2 - 8) - 3, sy * (W/2 - 5) - 3, wall - 0.01])
                cube([6, 6, esp_standoff + 0.01]);
        // butees sur les 2 cotes longs et a l'extremite opposee a l'USB
        for (sy = [-1, 1])
            translate([-L/2 + 6, sy * (W/2 + 0.8) - 0.8, wall - 0.01]) cube([L - 12, 1.6, h]);
        translate([-L/2 - 1.6, -6, wall - 0.01]) cube([1.6, 12, h]);
    }
}

module back_cover() {
    back_d = out_d - front_d;
    ring_wall = 1.2;
    difference() {
        rrect(out_w, out_h, back_d, corner);
        translate([0, 0, wall]) rrect(out_w - 2*wall, out_h - 2*wall, back_d, corner - wall/2);
        // ouverture USB-C : paroi du bas, face a l'extremite USB de la carte
        translate([esp_x - usb_w/2, -out_h/2 - 1, wall + esp_standoff + 1.6 + 1.5 - (usb_h + 2)/2])
            cube([usb_w, wall + 2, usb_h + 2]);
        // grille du haut-parleur au dos (anneaux de trous)
        translate([spk_x, spk_y, -1]) {
            for (a = [0 : 45 : 315]) rotate(a) translate([spk_d/4, 0, 0]) cylinder(d = 2.2, h = wall + 2);
            for (a = [0 : 30 : 330]) rotate(a) translate([spk_d/2 - 3.5, 0, 0]) cylinder(d = 2.2, h = wall + 2);
            cylinder(d = 2.2, h = wall + 2);
        }
        // trous de vis (passage)
        for (p = posts()) translate([p[0], p[1], -1]) cylinder(d = 2.8, h = wall + 2);
    }
    esp_cradle();
    // anneau de maintien du haut-parleur
    translate([spk_x, spk_y, wall - 0.01]) difference() {
        cylinder(d = spk_d + 2*ring_wall + tol, h = min(spk_h + 1, back_d - wall));
        translate([0, 0, -0.01]) cylinder(d = spk_d + tol, h = back_d);
    }
}

if (part == "front") front_shell();
if (part == "back")  back_cover();
module assembled() {
    color("#c8d84a") front_shell();
    // couvercle retourne (rotation autour de Y) et pose sur la coque avant
    color("#8fa31c") translate([0, 0, out_d]) rotate([0, 180, 0]) back_cover();
}
if (part == "assembled") assembled();
// vue d'apercu : face avant vers le haut, haut du robot vers le haut de l'ecran
if (part == "view") translate([0, 0, out_d]) rotate([0, 180, 0]) assembled();
if (part == "section") difference() {   // coupe pour voir l'interieur
    assembled();
    translate([0, -100, -10]) cube([100, 200, 100]);
}
if (part == "both") {
    front_shell();
    translate([out_w + 10, 0, 0]) back_cover();
}
