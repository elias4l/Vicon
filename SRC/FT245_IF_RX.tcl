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
add_wave {{/TOP/FT245_inst/rd_en}} -name USER_RD_EN
add_wave {{/TOP/FT245_inst/ready}} -name READY
add_wave {{/TOP/FT245_inst/DOUT}} -name DOUT -radix hex
# Lado conexion FT245
add_wave {{/TOP/FT245_inst/RXEn}} -name RXEn
add_wave {{/TOP/FT245_inst/RXEn_sync}} -name RXEn_SYNC
add_wave {{/TOP/FT245_inst/RDn}} -name RDn
add_wave {{/TOP/FT245_inst/DATA}} -name DATA -radix hex

add_wave {{/TOP/FT245_inst/modo_rx_reg}} -name MODO_RX
add_wave {{/TOP/FT245_inst/entrada_reg}} -name ENTRADA_REG -radix hex
add_wave {{/TOP/FT245_inst/state_reg}} -name ESTADO

# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/clk} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns

# valor inicial de las señales de entrada. Pulsadores en reposo
add_force {/TOP/MRST} -radix hex {0 0ns}
add_force {/TOP/User_rd_en} -radix hex {0 0ns}
# ya hay un dato en el FT245
add_force {/TOP/JB} -radix hex {A5 0ns}
add_force {/TOP/JC[0]} -radix bin {0 0ns}

# avanzar simulacion. OBSERVA que lo hacemos en multiplos del periodo de reloj
run 100 ns

## TEST
# Un pulso: activamos la entrada y la desactivamos transcurrido el tiempo deseado
add_force {/TOP/User_rd_en} -radix hex {1 0ns} {0 10ns}

run 100ns

# FTDI deja de tener un dato
add_force {/TOP/JC[0]} -radix bin {1 0ns}
add_force {/TOP/JB} -radix hex {ZZ 0ns}

run 100ns