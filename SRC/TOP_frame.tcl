#############################################################################
# Plantilla basica para script de simulacion
# Emilio Elias Sujar Overbury 09055901L
#############################################################################
# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart

# renombra una seÃ±al como un alias en VHDL
add_wave {{/TOP/FT245_inst/clk}} -name CLK
# otros alias interesantes
add_wave {{/TOP/MRST}} -name RESET
# Interfaz de usuario
# CAM IN
add_wave {{/TOP/JA(4)}} -name CAM_PCLK
add_wave {{/TOP/JA(6)}} -name CAM_VSYNC
add_wave {{/TOP/JA(2)}} -name CAM_HSYNC
add_wave {{/TOP/CAM_PCLK_sync}} -name CAM_PCLK_sync
add_wave {{/TOP/CAM_VSYNC_sync}} -name CAM_VSYNC_sync
add_wave {{/TOP/CAM_HSYNC_sync}} -name CAM_HSYNC_sync
add_wave {{/TOP/cont_dato}} -name CAM_DATA_sync -radix hex
# CAM_read
add_wave {{/TOP/cam_read_inst/enable}} -name CAM_read_enable
add_wave {{/TOP/cam_read_inst/DOUT}} -name CAM_read_DOUT -radix hex
# FTDI RX
add_wave {{/TOP/FT245_inst/TXEn}} -name FT245_TXEn
add_wave {{/TOP/FT245_inst/DATA}} -name FT245_DATA -radix hex


# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/clk} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns
add_force {/TOP/MRST} -radix bin {1 0ns} {0 80ns}
# definimos CAM_PCLK como un reloj con periodo de 83,33ns (12MHz). Aproximamos a 80ns (12.5MHz). Valor inicial 0
add_force {/TOP/JA(4)} -radix bin {0 0ns} {1 40ns} -repeat_every 80ns
# avanzar simulacion.
run 240 ns

# VSYNC. 480 líneas activo y 20 líneas inactivo. 480 × 127840ns = 61363200ns. 500 × 127840ns = 63920000ns.
add_force {/TOP/JA(6)} -radix bin {1 0ns} {0 61363200ns} -repeat_every 63920000ns
# HSYNC. 1280 ciclos activo (1280x80=102400ns), 318 ciclos inactivo (25440ns). Periodo de línea = 127840ns. Comienza 6 ciclos despues de comenzar VSYNC (480ns).
add_force {/TOP/JA(2)} -radix bin {0 0ns} {1 480ns} {0 102880ns} -repeat_every 127840ns
add_force {/TOP/cam_read_inst/enable} -radix bin {0 0ns} {1 1000ns} {0 2000ns}
# avanzar simulacion. OBSERVA que lo hacemos en multiplos del periodo de reloj
run 200000 ns
