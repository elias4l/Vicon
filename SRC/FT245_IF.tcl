#############################################################################
# Validacion modulo FT245_IF.vhd
# Plantilla basica para script de simulacion
#############################################################################

# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart
remove_wave [get_waves -r *]

add_wave {{/TOP/FT245_inst/DATA}}
# Mostrar señales de TX
add_wave {{/TOP/FT245_inst/TXEn}}
add_wave {{/TOP/FT245_inst/WRn}}
# Mostrar señales de RX
add_wave {{/TOP/FT245_inst/RXEn}}
add_wave {{/TOP/FT245_inst/RDn}}

# Mostrar señales externas
add_wave {{/TOP/FT245_inst/clk}}
add_wave {{/TOP/FT245_inst/reset}}
add_wave {{/TOP/FT245_inst/DIN}}
add_wave {{/TOP/FT245_inst/wrn_rd}}
add_wave {{/TOP/FT245_inst/DOUT}}
add_wave {{/TOP/FT245_inst/enable}}
add_wave {{/TOP/FT245_inst/ready}}
# Mostrar señales internas
add_wave {{/TOP/FT245_inst/state_reg}}
add_wave {{/TOP/FT245_inst/TXEn_sync}}
add_wave {{/TOP/FT245_inst/RXEn_sync}}
add_wave {{/TOP/FT245_inst/entrada_reg}}
add_wave {{/TOP/FT245_inst/salida_reg}}
add_wave {{/TOP/FT245_inst/modo_rx_reg}}

# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/FT245_inst/clk} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns
# entradas inicialmente inactivas
add_force {/TOP/FT245_inst/reset} -radix bin {1 0ns} {0 30ns}
add_force {/TOP/FT245_inst/enable} -radix bin {0 0ns}
add_force {/TOP/FT245_inst/wrn_rd} -radix bin {0 0ns}
add_force {/TOP/FT245_inst/TXEn} -radix bin {1 0ns}
add_force {/TOP/FT245_inst/RXEn} -radix bin {1 0ns}
add_force {/TOP/FT245_inst/DIN} -radix hex {00 0ns}
run 50 ns

#############################################################################
## TEST. RESET.
#############################################################################
# 50ns ->
remove_forces {/TOP/JB}
# Reset estando en modo TX (wrn_rd = 0). Debe volver a idle, con ready y WRn en alto.
# Caso TXEn ya estaba bajo.
add_force {/TOP/FT245_inst/DIN} -radix hex {00 0ns} {AA 10ns}
add_force {/TOP/FT245_inst/enable} -radix bin {0 0ns} {1 10ns} {0 20ns}
# add_force {/TOP/FT245_inst/wrn_rd} -radix bin {1 0ns} {0 10ns} {1 20ns}
# WRn baja a los 45ns. FTDI sube TXEn a los 14ns, es decir 59 ns. Se produce el reset antes.
add_force {/TOP/FT245_inst/TXEn} -radix bin {0 0ns} {1 59ns}
add_force {/TOP/FT245_inst/reset} -radix bin {0 0ns} {1 55ns} {0 65ns}
run 100 ns
# 150ns ->
remove_forces {/TOP/JB}
# Reset estando en modo RX. Debe volver a idle. 
# Caso RXEn ya estaba bajo.
add_force {/TOP/FT245_inst/RXEn} -radix bin {0 0ns}
# DATA disponible max 14ns tras bajar RDn (35ns), min hasta 1ns tras subir RDn (65ns). Se produce reset antes.
add_force {/TOP/JB} -radix hex {AA 49ns} {0 66ns}
add_force {/TOP/FT245_inst/enable} -radix bin {0 0ns} {1 10ns} {0 20ns}
add_force {/TOP/FT245_inst/wrn_rd} -radix bin {0 0ns} {1 10ns}
add_force {/TOP/FT245_inst/reset} -radix bin {0 0ns} {1 60ns} {0 70ns}
run 100 ns

#############################################################################
## TEST. TX.
#############################################################################
# 250ns ->
remove_forces {/TOP/JB}
# TX de un frame en escala de grises (comando x01).
# Caso TXEn inicialmente alto, baja a los 30ns. TXEN_sync a los 45ns.
add_force {/TOP/FT245_inst/DIN} -radix hex {01 0ns}
add_force {/TOP/FT245_inst/enable} -radix bin {0 0ns} {1 10ns} {0 20ns}
add_force {/TOP/FT245_inst/wrn_rd} -radix bin {1 0ns} {0 10ns}
# WRn baja a los 75ns. FTDI sube TXEn a los 14ns, es decir 89 ns.
add_force {/TOP/FT245_inst/TXEn} -radix bin {1 0ns} {0 30ns} {1 89ns}
run 150 ns
# Vuelve a idle, DATA muestra el dato que habia en DIN. Enable bajo.

#############################################################################
## TEST. RX.
#############################################################################
# 400ns ->
remove_forces {/TOP/JB}
# RX de un comando reset (x80).
# Caso RXEn inicalmente alto, baja a los 30ns. RXEn_sync a los 45ns.
add_force {/TOP/FT245_inst/RXEn} -radix bin {1 0ns} {0 30ns} {1 96ns}
add_force {/TOP/FT245_inst/enable} -radix bin {0 0ns} {1 10ns} {0 20ns}
add_force {/TOP/FT245_inst/wrn_rd} -radix bin {0 0ns} {1 10ns}
# DATA disponible max 14ns tras bajar RDn (65ns), min hasta 1ns tras subir RDn (95ns).
add_force {/TOP/JB} -radix hex {80 79ns} {0 96ns}
run 150 ns
# Vuelve a idle, DOUT muestra el dato que habia en DATA. Enable bajo.