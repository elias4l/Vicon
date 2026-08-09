----------------------------------------------------------------------------------
-- Este modulo controla el resto de modulos de la FPGA.
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
-- CTRL_inst: entity work.CONTROL
-- port map (
--     clk     => CLK, -- i
--     reset   => MRST, -- i
    
--     CAM_read --------------------------
--     CAM_read_reset => CtrlCAM_read_reset,-- o
--     CAM_read_en => CtrlCAM_read_en,-- o
--     CAM_read_color => CtrlCAM_read_color,-- o
--     CAM_pclk_tick => CtrlCAM_pclk_tick,-- i
    
--     FIFO interface -------------------
--     FIFO_reset => CtrlFIFO_reset, -- o
--     FIFO_PUSH => CtrlFIFO_PUSH, -- i
--     FIFO_POP => CtrlFIFO_POP, -- o
--     FIFO_EMPTY => CtrlFIFO_EMPTY, -- i
    
--     FTDI_IF interface ----------------
--     FTDI_IF_en => CtrlFTDI_IF_en, -- o
--     FTDI_IF_ready => CtrlFTDI_IF_ready, -- i
--     FTDI_IF_wrn_rd => CtrlFTDI_IF_wrn_rd, -- o
--     FTDI_IF_DOUT => CtrlFTDI_IF_DOUT, -- i(7:0)
--     FTDI_IF_RXEn => CtrlFTDI_IF_RXEn, -- i
--     FTDI_IF_TXEn => CtrlFTDI_IF_TXEn, -- i
-- );


entity CONTROL is
    Port (
        clk                 : in  STD_LOGIC;
        reset               : in  STD_LOGIC;
        -- CAM_read
        CAM_read_reset      : out STD_LOGIC;
        CAM_read_en         : out STD_LOGIC;
        CAM_read_color      : out STD_LOGIC;
        CAM_pclk_tick       : in  STD_LOGIC;
        -- FIFO interface
        FIFO_reset          : out STD_LOGIC;
        FIFO_PUSH           : in  STD_LOGIC;
        FIFO_POP            : out STD_LOGIC;
        FIFO_EMPTY          : in  STD_LOGIC;
        -- FTDI_IF interface
        FTDI_IF_en          : out STD_LOGIC;
        FTDI_IF_ready       : in  STD_LOGIC;
        FTDI_IF_wrn_rd      : out STD_LOGIC;
        FTDI_IF_DOUT        : in  STD_LOGIC_VECTOR(7 downto 0);
        FTDI_IF_RXEn        : in  STD_LOGIC;
        FTDI_IF_TXEn        : in  STD_LOGIC
    );
end CONTROL;


architecture Behavioral of CONTROL is
    type state_type is (idle, RX_init_ftdi, RX_wait, RX_init_cam_read, RX_wait_pclk, TX_enable, TX_wait, TX_fifo_pop);
    signal state_reg, state_next: state_type;
    
    -- CAM_read
    signal CAM_read_reset_next, CAM_read_reset_reg : STD_LOGIC;
    signal CAM_read_en_next, CAM_read_en_reg : STD_LOGIC;
    signal CAM_read_color_next, CAM_read_color_reg : STD_LOGIC;
    -- FIFO interface
    signal FIFO_reset_next, FIFO_reset_reg : STD_LOGIC;
    signal FIFO_POP_next, FIFO_POP_reg : STD_LOGIC;
    -- FTDI_IF interface
    signal FTDI_IF_en_next, FTDI_IF_en_reg : STD_LOGIC;
    signal FTDI_IF_wrn_rd_next, FTDI_IF_wrn_rd_reg : STD_LOGIC;

begin
--  Proceso para modelar el registro de estado. Unico bloque sincrono.
    REG: process (clk, reset) -- el reset de la FSM debe ser ASÍNCRONO.
    begin
        if reset='1' then
            state_reg <= idle;
            CAM_read_reset_reg <= '1';
            CAM_read_en_reg <= '0';
            CAM_read_color_reg <= '0';
            FIFO_reset_reg <= '1';
            FIFO_POP_reg <= '0';
            FTDI_IF_en_reg <= '0';
            FTDI_IF_wrn_rd_reg <= '1';
        elsif rising_edge(clk) then-- Las salidas deben ser registradas: olvida si son tipo Moore o Mealy.
            state_reg <= state_next;
            CAM_read_reset_reg <= CAM_read_reset_next;
            CAM_read_en_reg <= CAM_read_en_next;
            CAM_read_color_reg <= CAM_read_color_next;
            FIFO_reset_reg <= FIFO_reset_next;
            FIFO_POP_reg <= FIFO_POP_next;
            FTDI_IF_en_reg <= FTDI_IF_en_next;
            FTDI_IF_wrn_rd_reg <= FTDI_IF_wrn_rd_next;
        end if; -- proceso sincrono, no necesita sentencia else.
    end process REG;
        
    
--  Proceso para modelar la lógica de estado siguiente. 
    COMB: process (state_reg, CAM_pclk_tick, FIFO_PUSH, FIFO_EMPTY, FTDI_IF_ready, FTDI_IF_RXEn, FTDI_IF_TXEn, FTDI_IF_DOUT)
    begin
    --EC34. Asignación por defecto: simplifica el código y evita LATCHES no deseados.
    state_next <= state_reg;
    CAM_read_reset_next <= CAM_read_reset_reg;
    CAM_read_en_next <= CAM_read_en_reg;
    CAM_read_color_next <= CAM_read_color_reg;
    FIFO_reset_next <= FIFO_reset_reg;
    FIFO_POP_next <= FIFO_POP_reg;
    FTDI_IF_en_next <= FTDI_IF_en_reg;
    FTDI_IF_wrn_rd_next <= FTDI_IF_wrn_rd_reg;
    case state_reg is
        when idle =>
            CAM_read_en_next <= '0';
            FIFO_POP_next <= '0';
            FTDI_IF_en_next <= '0';
            if (FTDI_IF_ready = '1') and (FTDI_IF_RXEn = '0') then -- modo RX.
                state_next <= RX_init_ftdi;
            elsif (FTDI_IF_ready = '1') and (FTDI_IF_TXEn = '0') and (FIFO_EMPTY = '0') then -- modo TX.
                state_next <= TX_enable;
            end if;

    --TFM. RX del comando.
        when RX_init_ftdi => -- inicializa FTDI_IF en modo RX.
            FTDI_IF_en_next <= '1';
            FTDI_IF_wrn_rd_next <= '1';
            CAM_read_reset_next <= '1';
            FIFO_reset_next <= '1';
            if (FTDI_IF_ready = '0') then 
                state_next <= RX_wait;
            end if;

        when RX_wait => -- espera a que FTDI_IF_ready vuelva a '1', lo cual quiere decir que se ha leido el byte del comando.
            FTDI_IF_en_next <= '0';
            CAM_read_reset_next <= '0';
            FIFO_reset_next <= '0';
            if (FTDI_IF_ready = '1') then 
                state_next <= RX_init_cam_read;
            end if;

        when RX_init_cam_read => -- inicializa la lectura de la camara, activando CAM_read_en y CAM_read_color segun el comando recibido.
            CAM_read_en_next <= FTDI_IF_DOUT(0); -- BIT0 indica si se activa la lectura de la camara.
            CAM_read_color_next <= FTDI_IF_DOUT(1); -- BIT1 indica color o BN.
            if (FTDI_IF_DOUT(0) = '1') then
                state_next <= RX_wait_pclk;
            else
                state_next <= idle; -- si el comando no indica lectura de frame.
            end if;

        when RX_wait_pclk => -- espera a que se active la señal CAM_pclk_tick, lo cual indica que se ha recibido el primer byte valido de la camara.
            if (CAM_pclk_tick = '1') then
                state_next <= idle;
            end if;

    --TFM. TX del comando.
        when TX_enable =>
            FTDI_IF_wrn_rd_next <= '0';
            FTDI_IF_en_next <= '1';

            if FIFO_EMPTY = '1' then
                FTDI_IF_en_next <= '0';  -- cancela la petición inmediatamente, evitando lectura de FIFO vacía.
                state_next      <= idle;
            elsif FTDI_IF_ready = '0' then
                state_next <= TX_wait;
            end if;

        when TX_wait =>
            FTDI_IF_en_next <= '0';
            if (FTDI_IF_ready = '1') then 
                state_next <= TX_fifo_pop;
            end if;

        when TX_fifo_pop => -- al entrar se tiene que FIFO_POP_reg = '1', por lo que primero siempre durante minimo un ciclo activa la salida FIFO_POP.
            if (FIFO_POP_reg = '1') and (FIFO_PUSH = '0') then
                FIFO_POP_next <= '0';
                state_next <= TX_enable; -- si hay mas bytes en la FIFO.
            else
                FIFO_POP_next <= '1';
            end if;

    end case;
    end process COMB;
    
    CAM_read_en <= CAM_read_en_reg;
    CAM_read_color <= CAM_read_color_reg;
    CAM_read_reset <= CAM_read_reset_reg;
    FIFO_reset <= FIFO_reset_reg;
    FIFO_POP <= FIFO_POP_reg and not FIFO_PUSH; -- La FIFO no admite PUSH y POP simulatneos, siempre da prioridad a PUSH. Mientras PUSH este activo, no sale del estado TX_fifo_pop, por lo que se mantiene FIFO_POP a '1'.
    FTDI_IF_en <= FTDI_IF_en_reg;
    FTDI_IF_wrn_rd <= FTDI_IF_wrn_rd_reg;

end Behavioral;



