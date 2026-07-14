#############################################################################
# Plantilla basica para script de simulacion
# Emilio Elias Sujar Overbury 09055901L
#############################################################################
# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart

# renombra una señal como un alias en VHDL
add_wave {{/TOP/clk}} -name clk
# otros alias interesantes
add_wave {{/TOP/SW}} -name SW
add_wave {{/TOP/BTN}}
add_wave {{/TOP/FT245_TXEn}}
add_wave {{/TOP/FT245_D}}
add_wave {/TOP/FT245_WRn}
add_wave {{/TOP/UserDataIn}}
add_wave {{/TOP/User_wr_en}}
add_wave {{/TOP/User_rdy_flag}}
add_wave {{/TOP/FT245_TXEn_s}}
add_wave {{/TOP/FT245_WRn_s}}
add_wave {{/TOP/FT245_D_s}}
add_wave {{/TOP/MRST}}
add_wave {{/TOP/btn1_prev}}
add_wave {{/TOP/wr_pulse_s}}

# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/CLK} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns

# valor inicial de las señales de entrada. Pulsadores en reposo
# entradas a cero, TXEn_sync tardara 20ns en registrarse
add_force {/TOP/SW} -radix hex {0 0ns}
add_force {/TOP/BTN} -radix hex {0 0ns}
add_force {/TOP/MRST} -radix hex {0 0ns}

# avanzar simulacion. OBSERVA que lo hacemos en multiplos del periodo de reloj
run 100 ns

add_force {/TOP/FT245_TXEn} -radix hex {0 0ns}
add_force {/TOP/SW} -radix hex {AABB 0ns}
add_force {/TOP/BTN} -radix hex {0 0ns} {2 40ns}

# avanzar simulacion. OBSERVA que lo hacemos en multiplos del periodo de reloj
run 400 ns

add_force {/TOP/FT245_TXEn} -radix hex {1 0ns}
add_force {/TOP/SW} -radix hex {CCCC 15ns}
run 300 ns

add_force {/TOP/FT245_TXEn} -radix hex {0 0ns}

add_force {/TOP/BTN} -radix hex {0 0ns} {2 40ns}

# avanzar simulacion. OBSERVA que lo hacemos en multiplos del periodo de reloj
run 400 ns