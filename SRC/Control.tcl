#############################################################################
# Validacion modulo Control.vhd.
# Plantilla basica para script de simulacion.
#############################################################################

# reinicia la simulacion y el instante de simulacion vuelve a 0ns.
restart
remove_wave [get_waves -r *]
# Entradas generales
add_wave {{/TOP/CTRL_inst/clk}}
add_wave {{/TOP/CTRL_inst/reset}}
add_wave {{/TOP/CTRL_inst/reset_out}}
# CAM_read
add_wave {{/TOP/CTRL_inst/CAM_read_reset}}
add_wave {{/TOP/CTRL_inst/CAM_read_color}}
add_wave {{/TOP/CTRL_inst/CAM_read_en}}
add_wave {{/TOP/CTRL_inst/CAM_pclk_tick}}
# FIFO
add_wave {{/TOP/CTRL_inst/FIFO_reset}}
add_wave {{/TOP/CTRL_inst/FIFO_PUSH}}
add_wave {{/TOP/CTRL_inst/FIFO_POP}}
add_wave {{/TOP/CTRL_inst/FIFO_EMPTY}}
# FTDI_IF
add_wave {{/TOP/CTRL_inst/FTDI_IF_ready}}
add_wave {{/TOP/CTRL_inst/FTDI_IF_wrn_rd}}
add_wave {{/TOP/CTRL_inst/FTDI_IF_en}}
add_wave {{/TOP/CTRL_inst/FTDI_IF_RXEn}}
add_wave {{/TOP/CTRL_inst/FTDI_IF_TXEn}}
add_wave {{/TOP/CTRL_inst/FTDI_IF_DOUT}}
add_wave {{/TOP/CTRL_inst/state_reg}}

# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0.
add_force {/TOP/CLK} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns
# PCLK de la camara, aproximadamente 12MHz. Asi se genera CAM_pclk_tick.
add_force {/TOP/JA(4)} -radix bin {0 0ns} {1 40ns} -repeat_every 80ns
# entradas inicialmente inactivas
add_force {/TOP/MRST} -radix bin {1 0ns} {0 30ns} ;# Reset de PCLK_EDGE que genera CAM_PCLK_sync_tick.
add_force {/TOP/CTRL_inst/reset} -radix bin {1 0ns} {0 30ns}

add_force {/TOP/CTRL_inst/FIFO_PUSH}  -radix bin {0 0ns}
add_force {/TOP/CTRL_inst/FIFO_EMPTY} -radix bin {1 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_ready} -radix bin {0 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_DOUT}  -radix hex {00 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_RXEn}  -radix bin {1 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_TXEn}  -radix bin {1 0ns}
run 100 ns

#############################################################################
## TEST. RESET. PRIORIDAD.
#############################################################################
# 100ns ->
# FTDI activa simultaneamente RXEn y TXEn, el modulo de control debe dar prioridad a RX.
add_force {/TOP/CTRL_inst/FTDI_IF_ready} -radix bin {1 0ns} {0 25ns} ;# Un ciclo tras bajar FTDI_IF_en, FTDI_IF baja FTDI_IF_ready.
add_force {/TOP/CTRL_inst/FTDI_IF_RXEn}  -radix bin {0 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_TXEn}  -radix bin {0 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_DOUT}  -radix hex {01 65ns} ;# 4 ciclos despues, FTDI_IF saca el dato presente en el bus externo DATA.
add_force {/TOP/MRST} -radix bin {0 0ns} {1 70ns} {0 80ns}
run 100 ns
# Toma el camino RX. Vuelve al estado idle tras un reset asincrono.

#############################################################################
## TEST. COMANDO RESET.
#############################################################################
# 200ns ->
# FTDI dispone del comando 81. Debe de resetear pues el BIT 7 de reset tiene prioridad sobre el BIT0 de TX.
add_force {/TOP/CTRL_inst/FTDI_IF_ready} -radix bin {1 0ns} {0 25ns}  {1 85ns};# Un ciclo tras bajar FTDI_IF_en, FTDI_IF baja FTDI_IF_ready. # Sube un ciclo despues de subir RXEn.
add_force {/TOP/CTRL_inst/FTDI_IF_RXEn}  -radix bin {0 0ns} {1 75ns} ;# RXEn sube entre 1 y 14 ns despues de subir RDn (65ns).
add_force {/TOP/CTRL_inst/FTDI_IF_TXEn}  -radix bin {1 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_DOUT}  -radix hex {81 65ns} ;# 4 ciclos despues, FTDI_IF saca el dato presente en el bus externo DATA.
run 120 ns
# Al tener el byte de comando leido BIT 7 a 1, activa la salida reset_out.

#############################################################################
## TEST. RX.
#############################################################################
add_force {/TOP/MRST} -radix bin {1 0ns} {0 10ns}
run 30 ns
# 350ns ->
# FTDI dispone del comando 03. Debe solicitar un frame a color.
add_force {/TOP/CTRL_inst/FTDI_IF_ready} -radix bin {1 0ns} {0 25ns}  {1 85ns};# Un ciclo tras bajar FTDI_IF_en, FTDI_IF baja FTDI_IF_ready. # Sube un ciclo despues de subir RXEn.
add_force {/TOP/CTRL_inst/FTDI_IF_RXEn}  -radix bin {0 0ns} {1 75ns} ;# RXEn sube entre 1 y 14 ns despues de subir RDn (65ns).
add_force {/TOP/CTRL_inst/FTDI_IF_TXEn}  -radix bin {1 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_DOUT}  -radix hex {03 65ns} ;# 4 ciclos despues, FTDI_IF saca el dato presente en el bus externo DATA.
run 120 ns
# Tras leer el comando, activa correctamente las salidas de enable y color para CAM_READ.

#############################################################################
## TEST. TX.
#############################################################################
# 470ns ->
# FTDI baja TXEn y activa ready. Control solicita la trasnmision de un dato en FTDI_IF y luego activa POP en la FIFO.
add_force {/TOP/CTRL_inst/FTDI_IF_ready} -radix bin {1 0ns} {0 55ns}  {1 105ns};# Un ciclo tras bajar FTDI_IF_en, FTDI_IF baja FTDI_IF_ready. # Sube 4 ciclos despues de comprobar TXEn = 0 (65ns).
add_force {/TOP/CTRL_inst/FTDI_IF_RXEn}  -radix bin {1 0ns}
add_force {/TOP/CTRL_inst/FTDI_IF_TXEn}  -radix bin {0 0ns} {1 75ns} ;# Sube entre 1 y 14 ns tras bajar WRn (65ns).
add_force {/TOP/CTRL_inst/FIFO_PUSH}  -radix bin {0 0ns} {1 100ns} {0 150ns} ;# Se comprueba que POP no se activa si PUSH
add_force {/TOP/CTRL_inst/FIFO_EMPTY}  -radix bin {1 0ns} {0 30ns} {1 180ns}
run 200 ns
# Tras bajar TXEn con FTDI_ready alto, termina produciendose POP si no hay PUSH. Luego con FIFO_EMPTY vuelve a idle.
