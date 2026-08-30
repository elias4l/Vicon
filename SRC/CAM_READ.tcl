#############################################################################
# Validacion modulo CAM_READ.vhd
# Plantilla basica para script de simulacion
#############################################################################

# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart
remove_wave [get_waves -r *]
# Entradas generales
add_wave {{/TOP/cam_read_inst/enable}}
add_wave {{/TOP/cam_read_inst/color}}
add_wave {{/TOP/cam_read_inst/reset}}
add_wave {{/TOP/cam_read_inst/clk}}
add_wave {{/TOP/cam_read_inst/pclk_tick}}
add_wave {{/TOP/cam_read_inst/state_reg}}
# Camera IO
add_wave {{/TOP/CAM_PCLK_sync}}
add_wave {{/TOP/cam_read_inst/VSYNC}}
add_wave {{/TOP/cam_read_inst/HSYNC}}
add_wave {{/TOP/cam_read_inst/DIN}}
# Interfaz FIFO
add_wave {{/TOP/cam_read_inst/DOUT}}
add_wave {{/TOP/cam_read_inst/PUSH}}

# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/CLK} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns
# PCLK de la camara, aproximadamente 12MHz
add_force {/TOP/JA(4)} -radix bin {0 0ns} {1 40ns} -repeat_every 80ns
# entradas inicialmente inactivas
add_force {/TOP/MRST} -radix bin {1 0ns} {0 30ns} ;# Reset de PCLK_EDGE que genera CAM_PCLK_sync_tick
add_force {/TOP/cam_read_inst/reset} -radix bin {1 0ns} {0 30ns}
add_force {/TOP/cam_read_inst/enable} -radix bin {0 0ns}
add_force {/TOP/cam_read_inst/color} -radix bin {0 0ns}
add_force {/TOP/JA(6)} -radix bin {0 0ns} ;# CAM_VSYNC
add_force {/TOP/JA(2)} -radix bin {0 0ns} ;# CAM_HSYNC
add_force {/TOP/CAM_Data} -radix hex {00 0ns}
run 100 ns

#############################################################################
## TEST. COLOR. RESET.
#############################################################################
# 100ns ->
# Solicitud de un frame a color.
add_force {/TOP/cam_read_inst/enable} -radix bin {0 0ns} {1 15ns} {0 55ns} ;# Control mantiene enebla activo hasta el siguiente pclk_tick.
add_force {/TOP/cam_read_inst/color} -radix bin {0 0ns} {1 15ns}
# VSYNC, HSYNC y DATA cambian en el falnco de bajada de PCLK.
run 120 ns
# 220ns -> listo para leer un frame.
# Primeros 6 ciclos VSYNC activo. 
add_force {/TOP/JA(6)} -radix bin {1 0ns}
run 480ns
# Luego se activa HSYNC y comienzan a llegar los bytes Cb Y0 Cr Y1 ...
add_force {/TOP/JA(2)} -radix bin {1 0ns}
# Reset asincrono por ejemeplo a los 250 ns
add_force {/TOP/cam_read_inst/reset} -radix bin {0 0ns} {1 250ns} {0 300ns}
for {set pixel 0} {$pixel < 5} {incr pixel} {
    set dato [expr {$pixel % 256}]
    add_force {/TOP/CAM_Data} -radix unsigned $dato
    run 80 ns
}

#############################################################################
## TEST. BN.
#############################################################################
# 1100ns ->
# entradas inicialmente inactivas
add_force {/TOP/MRST} -radix bin {1 0ns} {0 50ns} ;# Reset de PCLK_EDGE que genera CAM_PCLK_sync_tick
add_force {/TOP/cam_read_inst/reset} -radix bin {1 0ns} {0 50ns}
add_force {/TOP/cam_read_inst/enable} -radix bin {0 0ns}
add_force {/TOP/cam_read_inst/color} -radix bin {0 0ns}
add_force {/TOP/JA(6)} -radix bin {0 0ns} ;# CAM_VSYNC
add_force {/TOP/JA(2)} -radix bin {0 0ns} ;# CAM_HSYNC
add_force {/TOP/CAM_Data} -radix hex {00 0ns}
run 120 ns
# 1200ns ->
# Solicitud de un frame en escala de grises.
add_force {/TOP/cam_read_inst/enable} -radix bin {0 0ns} {1 15ns} {0 55ns} ;# Control mantiene enebla activo hasta el siguiente pclk_tick.
add_force {/TOP/cam_read_inst/color} -radix bin {0 0ns}
# VSYNC, HSYNC y DATA cambian en el falnco de bajada de PCLK.
run 120 ns
# 1320ns -> listo para leer un frame.
# Primeros 6 ciclos VSYNC activo. 
add_force {/TOP/JA(6)} -radix bin {1 0ns}
run 480ns
# Luego se activa HSYNC y comienzan a llegar los bytes Cb Y0 Cr Y1 ...
add_force {/TOP/JA(2)} -radix bin {1 0ns}
# Simula una linea de 4 pixeles
for {set pixel 1} {$pixel < 9} {incr pixel} {
    set dato [expr {$pixel % 256}]
    add_force {/TOP/CAM_Data} -radix unsigned $dato
    run 80 ns
}
# Blanking entre dos lineas 8 ciclos
add_force {/TOP/JA(2)} -radix bin {0 0ns} ;# CAM_HSYNC
run 640 ns
# Simula una linea de 4 pixeles
add_force {/TOP/JA(2)} -radix bin {1 0ns} ;# CAM_HSYNC
for {set pixel 9} {$pixel < 17} {incr pixel} {
    set dato [expr {$pixel % 256}]
    add_force {/TOP/CAM_Data} -radix unsigned $dato
    run 80 ns
}
# Blanking final de frame. 6 ciclos HSYNC bajo seguido de VSYNC bajo.
add_force {/TOP/JA(2)} -radix bin {0 0ns} ;# CAM_HSYNC
add_force {/TOP/JA(6)} -radix bin {1 0ns} {0 480ns} ;# CAM_VSYNC
run 640 ns
# Se recogen correctamente los bytes pares, se generan las senales PUSH para la fifo correctamente. Al finalizar se vuelve al estado idle para esperar al siguiente enable.
