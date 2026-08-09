#############################################################################
# Plantilla basica para script de simulacion
#############################################################################
# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart

# Mostrar señales de la RAM FIFO externas
add_wave {{/TOP/FIFO_inst/CLK}}
add_wave {{/TOP/FIFO_inst/PUSH}}
add_wave {{/TOP/FIFO_inst/POP}}
add_wave {{/TOP/FIFO_inst/DIN}}
add_wave {{/TOP/FIFO_inst/DOUT}}
add_wave {{/TOP/FIFO_inst/FULL}}
add_wave {{/TOP/FIFO_inst/EMPTY}}
add_wave {{/TOP/FIFO_inst/RST}}
# Mostrar señales internas
# add_wave {{/TOP/FIFO_inst/RAM}}
add_wave {{/TOP/FIFO_inst/contador}}
add_wave {{/TOP/FIFO_inst/wr_en}}
add_wave {{/TOP/FIFO_inst/rd_en}}


# Aplicacion de estimulos basicos
# definimos CLK como un reloj con periodo de 10ns (100MHz). Valor inicial 0
add_force {/TOP/FIFO_inst/CLK} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns
# entradas a cero
add_force {/TOP/FIFO_inst/RST} -radix bin {0 0ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns}
add_force {/TOP/FIFO_inst/POP} -radix bin {0 0ns}
add_force {/TOP/FIFO_inst/DIN} -radix hex {00 0ns}


### efecto del reset

# Primero introducimos datos
add_force {/TOP/FIFO_inst/DIN} -radix hex {0 0ns} {04 10ns} {0 40ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 20ns} {0 30ns}
run 50 ns
add_force {/TOP/FIFO_inst/DIN} -radix hex {0 0ns} {80 10ns} {0 40ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 20ns} {0 30ns}
run 50 ns
# Reset
add_force {/TOP/FIFO_inst/RST} -radix bin {0 0ns} {1 20ns} {0 30ns}
run 50 ns

### efecto del PUSH cuando se activa de forma aislada en distintas situaciones (FIFO llena, FIFO vacia y FIFO ni llena ni vacia).

# Si la RAM tiene un bus de direcciones de 3 bits, con 8 ciclos de 10 ns se debe de llenar.
add_force {/TOP/FIFO_inst/DIN} -radix hex {A0 0ns} {A1 20ns} {A2 40ns} {A3 60ns} {A4 80ns} {A5 100ns} {A6 120ns} {A7 140ns} {A8 160ns} {A9 180ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 10ns} {0 20ns} {1 30ns} {0 40ns} {1 50ns} {0 60ns} {1 70ns} {0 80ns} {1 90ns} {0 100ns} {1 110ns} {0 120ns} {1 130ns} {0 140ns} {1 150ns} {0 160ns} {1 170ns} {0 180ns}
# Y un reset con FIFO full
add_force {/TOP/FIFO_inst/RST} -radix bin {0 0ns} {1 180ns} {0 190ns}
run 200 ns


### efecto del POP cuando se activa de forma aislada en distintas situaciones (FIFO llena, FIFO vacia y FIFO ni llena ni vacia).
# se llena la FIFO
add_force {/TOP/FIFO_inst/DIN} -radix hex {B0 0ns} {B1 20ns} {B2 40ns} {B3 60ns} {B4 80ns} {B5 100ns} {B6 120ns} {B7 140ns} {B8 160ns} {B9 180ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 10ns} {0 20ns} {1 30ns} {0 40ns} {1 50ns} {0 60ns} {1 70ns} {0 80ns} {1 90ns} {0 100ns} {1 110ns} {0 120ns} {1 130ns} {0 140ns} {1 150ns} {0 160ns} {1 170ns} {0 180ns}
run 200 ns
# Estando la FIFO llena, se pasa a vaciarla activando POP de forma aislada.
add_force {/TOP/FIFO_inst/POP} -radix bin {0 0ns} {1 10ns} {0 20ns} {1 30ns} {0 40ns} {1 50ns} {0 60ns} {1 70ns} {0 80ns} {1 90ns} {0 100ns} {1 110ns} {0 120ns} {1 130ns} {0 140ns} {1 150ns} {0 160ns} {1 170ns} {0 180ns}
# Y un reset con FIFO full
add_force {/TOP/FIFO_inst/RST} -radix bin {0 0ns} {1 180ns} {0 190ns}
run 200 ns

### efecto del PUSH y POP cuando se activan de forma simult�nea en distintas situaciones (FIFO llena, FIFO vacia y FIFO ni llena ni vacia).
#FIFO vacia
add_force {/TOP/FIFO_inst/DIN} -radix hex {0 0ns} {C0 10ns} {0 40ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 20ns} {0 30ns}
add_force {/TOP/FIFO_inst/POP} -radix bin {0 0ns} {1 20ns} {0 30ns}
run 50 ns
# se introducen dos valores en la FIFO
add_force {/TOP/FIFO_inst/DIN} -radix hex {C1 0ns} {C2 20ns} 
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 10ns} {0 20ns} {1 30ns} {0 40ns}
run 50 ns
#FIFO ni llena ni vacia
add_force {/TOP/FIFO_inst/DIN} -radix hex {0 0ns} {C5 10ns} {0 40ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 20ns} {0 30ns}
add_force {/TOP/FIFO_inst/POP} -radix bin {0 0ns} {1 20ns} {0 30ns}
run 50 ns
# se introducen mas valores en la FIFO
add_force {/TOP/FIFO_inst/DIN} -radix hex {C6 0ns} {C7 20ns} {C8 40ns} {C9 60ns} {CA 80ns} {CB 100ns} {CC 120ns} {CD 140ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 10ns} {0 20ns} {1 30ns} {0 40ns} {1 50ns} {0 60ns} {1 70ns} {0 80ns} {1 90ns} {0 100ns} {1 110ns} {0 120ns} {1 130ns} {0 140ns}
run 150 ns
#FIFO llena
add_force {/TOP/FIFO_inst/DIN} -radix hex {0 0ns} {D0 10ns} {0 40ns}
add_force {/TOP/FIFO_inst/PUSH} -radix bin {0 0ns} {1 20ns} {0 30ns}
add_force {/TOP/FIFO_inst/POP} -radix bin {0 0ns} {1 20ns} {0 30ns}
run 50 ns


### Activación/desactivación de las señales de estado (FULL / EMPTY)
### orden de lectura de los datos correcto






