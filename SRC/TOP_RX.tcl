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
add_wave {{/TOP/FT245_inst/rd_en}} -name FT245_USER_RD_EN
add_wave {{/TOP/FT245_inst/ready}} -name FT245_READY
add_wave {{/TOP/FT245_inst/DOUT}} -name FT245_DOUT -radix hex
add_wave {{/TOP/led}} -name LED -radix hex
# FTDI RX
add_wave {{/TOP/JC[0]}} -name RXEn
add_wave {{/TOP/FT245_inst/RXEn_sync}} -name FT245_RXEn_SYNC
add_wave {{/TOP/FT245_inst/DATA}} -name FT245_DATA -radix hex
add_wave {{/TOP/JC[1]}} -name RDn

# Adicionales lado conexion FT245
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
# RXEn, dato disponible para leer a los 80ns.
add_force {/TOP/JC[0]} -radix bin {1 0ns} {0 75ns}
# TXEn, no usado aqui.
add_force {/TOP/JC[4]} -radix bin {1 0ns}
# CLKOUT, no usado aqui.
add_force {/TOP/JC[6]} -radix bin {0 0ns}

# avanzar simulacion. OBSERVA que lo hacemos en multiplos del periodo de reloj
run 100 ns

## TEST, usuario pulsa BtnR, generando un tick de 10ns asociado a rd_en.
## Lo correcto es que FTDI_IF baje RDn, tras 14ns FTDI debe aportar el dato en DATA, y tras 30ns FTDI_IF debe leer DATA y subir RDn.
add_force {/TOP/FT245_inst/rd_en} -radix bin {1 0ns} {0 10ns}

# FTDI deshabilitará RXEn 14ns tras subir RDn, y DATA tambien deja de estar disponible.
add_force {/TOP/JC[0]} -radix bin {0 0ns} {1 69ns} {0 120ns} {1 170ns}
# DATA se habilita tras 14ns de bajar RDn y se deshabilita tras 14ns de subir RDn.
add_force {/TOP/JB} -radix hex {ZZ 0ns} {77 39ns} {ZZ 69ns}

run 200ns

## TEST, ahora FTDI habilita dato disponible, bajando RXEn y aportando DATA, pero el usuario no pulsa BtnR asociado a rd_en.
## RXEn baja. Lo correcto es que no se debe leer el DATO.
add_force {/TOP/JC[0]} -radix bin {0 0ns}
# DATA en relaidad no tiene datos, pero para corroborar que no se lee ningun dato.
add_force {/TOP/JB} -radix hex {88 14ns}

run 200ns