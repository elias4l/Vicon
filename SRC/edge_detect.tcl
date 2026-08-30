#############################################################################
# Validacion modulo edge_detect.vhd
# Emilio Elias Sujar Overbury 09055901L
#############################################################################
# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart
remove_wave [get_waves -r *]

# renombra una señal como un alias en VHDL
add_wave {{/TOP/PCLK_EDGE/clk}} -name CLK
add_wave {{/TOP/PCLK_EDGE/reset}} -name RST
add_wave {{/TOP/PCLK_EDGE/level}} -name IN
add_wave {{/TOP/PCLK_EDGE/tick}} -name TICK

# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/PCLK_EDGE/clk} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns
# definimos CAM_PCLK como un reloj con periodo de 80ns (12.5MHz). Valor inicial 0.
add_force {/TOP/PCLK_EDGE/level} -radix bin {0 0ns} {1 40ns} -repeat_every 80ns

## TEST. Flanco ascendente/descendente IN.
# TICK unicamente debe activarse 5ns en el flanco de subida de IN.
add_force {/TOP/PCLK_EDGE/reset} -radix bin {0 0ns}
run 240 ns

## TEST RESET
# Si RST activo, TICK no debe activarse nunca.
add_force {/TOP/PCLK_EDGE/reset} -radix bin {1 0ns} {0 200ns}
run 240 ns
