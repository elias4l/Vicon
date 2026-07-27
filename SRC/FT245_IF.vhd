----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Emilio Elias Sujar Overbury
-- 
-- Create Date: 04.06.2025 16:55:21
-- Design Name: 
-- Module Name: FT245_IF - Behavioral
-- Project Name: PARALELO
-- Target Devices: 
-- Tool Versions: 
-- Description: This proyect implements a FSM that controls asyncronous writing on a FT245 interface. MCLK operates at 100MHz.
-- There are two main segments, one secuencial process for state control (with asyncronous reset), and one combinational process for next state and other signals.
-- Input signal TXEn is syncronized by passing through two FF.
-- Template instance example is shown for reference.
-- ADDED RX.
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


-- ===============================
--    INSTANCE TEMPLATE
-- ===============================
-- FT245_inst: entity FT245_IF
-- port map (
--     clk     => MCLK, -- i
--     reset   => MRST, -- i
    
    -- User IO ---------------------------
--     DIN     => UserDataIn,     -- i[7:0]
--     wrn_rd   => User_wrn_rd,     -- i
--     DOUT    => UserDataOut,    -- o[7:0]
--     ready   => User_rdy_flag,  -- o
    
    -- FT245-like interface --------------
--     TXEn    => FT245_TXEn,     -- i
--     WRn     => FT245_WRn,      -- o
--     RXEn    => FT245_RXEn,     -- i
--     RDn     => FT245_RDn,      -- o
--     DATA    => FT245_D         -- o[7:0]
-- );


entity FT245_IF is
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           DIN : in STD_LOGIC_VECTOR (7 downto 0);
           wrn_rd : in STD_LOGIC;
           DOUT : out STD_LOGIC_VECTOR (7 downto 0);
           ready : out STD_LOGIC;
           TXEn : in STD_LOGIC;
           WRn : out STD_LOGIC;
           RXEn : in STD_LOGIC;
           RDn : out STD_LOGIC;
           DATA : inout STD_LOGIC_VECTOR (7 downto 0));
end FT245_IF;

--EC34. Modelaremos la FSM para el control de escritura as ncrono en un interfaz tipo FT245.
architecture Behavioral of FT245_IF is
    type state_type is (idle, output_data, write_1, write_2, write_3,
                        read_1, read_2, read_3, read_4, wait_for_RXE_UP);
    signal state_reg, state_next: state_type;
--EC34. Trabajar con la versi n sincronizada de TXEn
    signal synchronizer_tx: STD_LOGIC_VECTOR (2 downto 0); -- Modulo M24.
    signal synchronizer_rx: STD_LOGIC_VECTOR (2 downto 0); -- Modulo M24.
    signal TXEn_sync: STD_LOGIC;
    signal RXEn_sync: STD_LOGIC;
    
    signal entrada_next, entrada_reg: STD_LOGIC_VECTOR (7 downto 0); -- para cada entrada, crearemos dos señales internas.
    signal salida_next, salida_reg: STD_LOGIC_VECTOR (7 downto 0); -- para cada salida, crearemos dos señales internas.
    signal RDn_next, RDn_reg: STD_LOGIC;
    signal WRn_next, WRn_reg: STD_LOGIC;
    signal ready_next, ready_reg: STD_LOGIC;

    signal modo_rx_reg, modo_rx_next: STD_LOGIC; -- 1 la FPGA libera DATA para recibir, 0 la FPGA conduce DATA para transmitir.

begin
--EC34. Utilizaremos dos segmentos de código:
--  un proceso para modelar el registro de estado. Unico bloque sincrono.
    REG: process (clk, reset) -- el reset de la FSM debe ser ASÍNCRONO.
    begin
        if reset='1' then
            state_reg <= idle;
            entrada_reg <= (others => '0');
            salida_reg <= (others => '0');
            ready_reg <= '1';   -- idle
            WRn_reg <= '1'; -- idle;
            RDn_reg <= '1'; -- idle;
            modo_rx_reg <= '0'; -- idle, por defecto bus DATA capturado para transmitir.
        elsif rising_edge(clk) then-- Las salidas deben ser registradas: olvida si son tipo Moore o Mealy.
            state_reg <= state_next;
            entrada_reg <= entrada_next;
            salida_reg <= salida_next;
            ready_reg <= ready_next;
            WRn_reg <= WRn_next;
            RDn_reg <= RDn_next;
            modo_rx_reg <= modo_rx_next;
        end if; -- proceso sincrono, no necesita sentencia else.
    end process REG;
        
    
--  otro proceso para modelar la lógica de estado siguiente. 
    COMB: process (state_reg, wrn_rd, TXEn_sync, RXEn_sync) 
    begin
    --EC34. Asignación por defecto: simplifica el código y evita LATCHES no deseados.
    state_next <= state_reg;
    entrada_next <= entrada_reg;
    salida_next <= salida_reg;
    ready_next <= ready_reg;
    WRn_next <= WRn_reg;
    RDn_next <= RDn_reg;
    modo_rx_next <= modo_rx_reg;
    case state_reg is
        when idle =>
            modo_rx_next <= '0'; -- bus DATA capturado, TX por defecto.
            ready_next <= '1';
            WRn_next <= '1';
            RDn_next <= '1';
            if (wrn_rd = '0') and (TXEn_sync = '0')  then -- pasamos a modo TX.
                state_next <= output_data;
            elsif (wrn_rd = '1') and (RXEn_sync = '0') then -- pasamos a modo RX.
                state_next <= read_1;
            end if;
    --TFM. Parte dedicada a la lectura asincrona.
        when read_1 => -- hay que bajar RDn y esperar t3 = 14ns.
            modo_rx_next <= '1'; -- bus DATA liberado (Z), se va a leer un dato.
            ready_next <= '0';
            RDn_next <= '0';
            state_next <= read_2;

        when read_2 =>
            state_next <= read_3;

        when read_3 =>
            state_next <= read_4;

        when read_4 => --tras pasar min t4 = 30ns desde que RDn = 0, se puede capturar el dato y subir RDn.
            entrada_next <= DATA;
            RDn_next <= '1';
            state_next <= wait_for_RXE_UP;

        when wait_for_RXE_UP =>
            if (RXEn_sync = '1') then 
                state_next <= idle;
            end if;
    --TFM. Parte anterior, dedicada a la escritura asincrona.        
        when output_data =>  -- una vez que TXEn = 0 ya se puede escribir en DATA.
            ready_next <= '0';
            WRn_next <= '1';
            salida_next <= DIN;
            state_next <= write_1;

        when write_1 =>
            WRn_next <= '0';
            state_next <= write_2;
        
        when write_2 =>
            state_next <= write_3;
        
        when write_3 =>
            state_next <= idle;
            
    end case;
    end process COMB;
    
    ready <= ready_reg;
    WRn <= WRn_reg;
    RDn <= RDn_reg;
    DATA <= (others => 'Z') when modo_rx_reg = '1' else salida_reg; -- TFM. Alta impedancia si esta en modo rx, salida_reg si esta en modo tx.
    DOUT <= entrada_reg; -- TFM. Salida de lectura asincrona.

-- EC34. Modelaremos un simple sincronizador de 2 FF. Codigo copiado de M24.
    process begin
        wait until rising_edge(clk);
        synchronizer_tx <= TXEn & synchronizer_tx(2 downto 1);
    end process;
    TXEn_sync <= synchronizer_tx(0);
    
    process begin
        wait until rising_edge(clk);
        synchronizer_rx <= RXEn & synchronizer_rx(2 downto 1);
    end process;
    RXEn_sync <= synchronizer_rx(0);

end Behavioral;



