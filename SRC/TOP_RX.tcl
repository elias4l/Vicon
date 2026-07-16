#############################################################################
# Plantilla basica para script de simulacion
# Emilio Elias Sujar Overbury 09055901L
#############################################################################
# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart

# renombra una señal como un alias en VHDL
add_wave {{/TOP/FT245_inst/clk}} -name CLK
# otros alias interesantes
add_wave {{/TOP/FT245_inst/reset}} -name RESET
# Interfaz de usuario
add_wave {{/TOP/btnR}} -name BTNR
add_wave {{/TOP/btnR_db}} -name BTNR_DB
add_wave {{/TOP/btnR_tick}} -name BTNR_TICK
add_wave {{/TOP/FT245_inst/rd_en}} -name FT245_USER_RD_EN
add_wave {{/TOP/FT245_inst/ready}} -name FT245_READY
add_wave {{/TOP/FT245_inst/DOUT}} -name FT245_DOUT -radix hex
add_wave {{/TOP/led}} -name LED -radix hex
# FTDI RX
add_wave {{/TOP/JC[0]}} -name RXEn
add_wave {{/TOP/FT245_inst/DATA}} -name FT245_DATA -radix hex
add_wave {{/TOP/JC[1]}} -name RDn

# Adicionales lado conexion FT245
add_wave {{/TOP/FT245_inst/RXEn_sync}} -name FT245_RXEn_SYNC
add_wave {{/TOP/JB}} -name JB -radix hex

add_wave {{/TOP/FT245_inst/state_reg}} -name FT245_ESTADO

# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/clk} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns

# valor inicial de las señales de entrada. Pulsadores en reposo
add_force {/TOP/sw} -radix hex {0000 0ns}
add_force {/TOP/btnC} -radix bin {0 0ns}
add_force {/TOP/btnU} -radix bin {0 0ns}
add_force {/TOP/btnD} -radix bin {0 0ns}
add_force {/TOP/btnL} -radix bin {0 0ns}
add_force {/TOP/btnR} -radix bin {0 0ns}
# Señales de entrada provenientes del FTDI.
# RXEn, llega un dato a los 80ns.
add_force {/TOP/JC[0]} -radix bin {1 0ns} {0 80ns} 
add_force {/TOP/JB} -radix hex {A5 80ns}
# TXEn, no usado aqui.
add_force {/TOP/JC[4]} -radix bin {1 0ns}
# CLKOUT, no usado aqui.
add_force {/TOP/JC[6]} -radix bin {0 0ns}

# avanzar simulacion. OBSERVA que lo hacemos en multiplos del periodo de reloj
run 100 ns

## TEST, usuario pulsa BtnR asociado a rd_en, Y TRAS 65ns el FTDI_IF BAJA RDn, SUBIENDOLO TRAS 95ns.
add_force {/TOP/btnR} -radix bin {1 0ns} {0 200ns}

# FTDI deshabilitará RXEn 14ns tras subir RDn, y DATA tambien deja de estar disponible.
add_force {/TOP/JC[0]} -radix bin {0 0ns} {1 114ns} {0 163ns} 
add_force {/TOP/JB} -radix hex {A5 0ns} {ZZ 114ns}

run 300ns

