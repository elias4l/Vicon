----------------------------------------------------------------------------------
-- Uso de la FIFO creada en EC32.
-- Incialmente se aÃ±aden bytes a la FIFO pulsando btnD y se mandan al FT245 pulsando btnU.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; --contador

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity TOP is
    Port ( sw : in STD_LOGIC_VECTOR (15 downto 0);
           btnC, btnU, btnL, btnR, btnD : in STD_LOGIC;
           led : out STD_LOGIC_VECTOR (15 downto 0);
           seg : out STD_LOGIC_VECTOR (6 downto 0);
           dp  : out STD_LOGIC;
           an : out STD_LOGIC_VECTOR (3 downto 0);
           -- FT245
           clk : in STD_LOGIC;
           JA : inout STD_LOGIC_VECTOR(7 downto 0);
           JB : inout STD_LOGIC_VECTOR(7 downto 0); -- Ahora DATA es inout.
           JC : inout STD_LOGIC_VECTOR(7 downto 0);
           JXADC : in STD_LOGIC_VECTOR(7 downto 0));

end TOP;


architecture Behavioral of TOP is
--aliases puerto JC
alias FT245_D: STD_LOGIC_VECTOR(7 downto 0) is JB;
alias FT245_RXEn : STD_LOGIC is JC(0); --JC1, K17 , -i
alias FT245_RDn  : STD_LOGIC is JC(1); --JC2, M18 , -o
alias FT245_SIWUn  : STD_LOGIC is JC(2); --JC3, N17 , -o
alias FT245_OEn  : STD_LOGIC is JC(3); --JC4, P18 , -o
alias FT245_TXEn : STD_LOGIC is JC(4); --JC7, L17 , -i
alias FT245_WRn  : STD_LOGIC is JC(5); --JC8, M19 , -o
alias CLOKOUT  : STD_LOGIC is JC(6); --JC9, P17 , -i
alias PWRSAVn  : STD_LOGIC is JC(7); --JC10, R18 , -o

--señales usadas en FT245_IF, lado FPGA
signal UserDataIn  : STD_LOGIC_VECTOR(7 downto 0);
signal UserDataOut  : STD_LOGIC_VECTOR(7 downto 0);
signal User_wr_en  : STD_LOGIC;
signal User_rd_en  : STD_LOGIC;
signal User_rdy_flag  : STD_LOGIC;
signal MRST   : STD_LOGIC := '0';


--signal cont_dato  : unsigned(7 downto 0) := (others => '0');

--señales usadas en la FIFO
signal FIFO_DIN : STD_LOGIC_VECTOR(7 downto 0);
signal FIFO_PUSH : STD_LOGIC;
signal FIFO_FULL : STD_LOGIC;
signal FIFO_DOUT : STD_LOGIC_VECTOR(7 downto 0);
signal FIFO_POP : STD_LOGIC;
signal FIFO_EMPTY : STD_LOGIC;

--señales de botones sin rebote
signal btnD_db : std_logic;
signal btnU_db : std_logic;
signal btnR_db : std_logic;

signal btnD_tick : std_logic;
signal btnU_tick : std_logic;
signal btnR_tick : std_logic;


begin
--botones usados sin rebote
    btnD_db_inst : entity work.db_fsm
    port map (
        clk   => CLK,
        reset => MRST,
        sw    => btnD,
        db    => btnD_db
    );

    btnU_db_inst : entity work.db_fsm
    port map (
        clk   => CLK,
        reset => MRST,
        sw    => btnU,
        db    => btnU_db
    );

    btnR_db_inst : entity work.db_fsm
    port map (
        clk   => CLK,
        reset => MRST,
        sw    => btnR,
        db    => btnR_db
    );

    btnD_edge_inst : entity work.edge_detect
    port map (
        clk   => CLK,
        reset => MRST,
        level => btnD_db,
        tick  => btnD_tick
    );

    btnU_edge_inst : entity work.edge_detect
    port map (
        clk   => CLK,
        reset => MRST,
        level => btnU_db,
        tick  => btnU_tick
    );

    btnR_edge_inst : entity work.edge_detect
    port map (
        clk   => CLK,
        reset => MRST,
        level => btnR_db,
        tick  => btnR_tick
    );

--instancia del controlador FT245
-- ===============================
--    INSTANCE TEMPLATE
-- ===============================
    FT245_inst: entity work.FT245_IF
    port map (
        clk     => CLK, -- i
        reset   => MRST, -- i
    
    -- User IO ---------------------------
        DIN     => UserDataIn,     -- i[7:0]
        wr_en   => User_wr_en,     -- i
        DOUT    => UserDataOut,    -- o[7:0] -- modo RX
        rd_en   => User_rd_en,     -- i -- modo RX
        ready   => User_rdy_flag,  -- o
    
    -- FT245-like interface --------------
        TXEn    => FT245_TXEn,     -- i
        WRn     => FT245_WRn,      -- o
        RDn     => FT245_RDn,       -- o -- modo RX
        RXEn    => FT245_RXEn,     -- o -- modo RX
        DATA(0) => FT245_D(0),
        DATA(1) => FT245_D(4),
        DATA(2) => FT245_D(1),
        DATA(3) => FT245_D(5),
        DATA(4) => FT245_D(2),
        DATA(5) => FT245_D(6),
        DATA(6) => FT245_D(3),
        DATA(7) => FT245_D(7)
    );

    -- conexionado restante del FT245_IF con el conector JB y JC.
    FT245_SIWUn <= '1';  -- no usados
    FT245_OEn <= '1';  -- no usados, solo para modo sincrono.
    PWRSAVn <= '1';  -- no usados 

    --instancia de la FIFO
    --B = anchura del Bus de direcciones.
    --W = anchura de los buses de datos DIN y DOUT.
    -- ===============================
    --    INSTANCE TEMPLATE
    -- ===============================
    FIFO_inst : entity work.FIFO
    port map (
        CLK   => CLK,
        RST   => MRST,

        DIN   => FIFO_DIN,
        PUSH  => FIFO_PUSH,
        FULL  => FIFO_FULL,

        DOUT  => FIFO_DOUT,
        POP   => FIFO_POP,
        EMPTY => FIFO_EMPTY
    );

    -- conexionado de la FIFO y del FT245_IF
    FIFO_POP <= btnU_tick and User_rdy_flag and not FIFO_EMPTY;
    User_wr_en <= FIFO_POP;

    process(clk)
    begin
        if rising_edge(clk) then
            if MRST = '1' then
                UserDataIn <= (others => '0');
            elsif FIFO_POP = '1' then
                UserDataIn <= FIFO_DOUT;
            end if;
        end if;
    end process;

    -- conexionado de la FIFO y de los pulsadores btnD y btnU
    FIFO_PUSH <= btnD_tick and not FIFO_FULL;


    -- conexionado BtnR y modo RX del FT245_IF
    User_rd_en <= btnR_tick;
    LED(7 downto 0) <= UserDataOut;

-- envio contador al FT245 lo mas rapido posible
--    process(clk)
--    begin
--        if rising_edge(clk) then
--            if User_rdy_flag = '1' then
--                User_wr_en <= '1';
--                cont_dato <= cont_dato + 1;
--            else
--                User_wr_en <= '0';
--            end if;
--        end if;
--    end process;

    --FIFO_DIN <= cont_dato;
    FIFO_DIN <= sw(7 downto 0);

    --indicadores
    seg <= SW(6 downto 0);
    dp  <= '1';
    an <= "1110";
    MRST <= btnC;
end Behavioral;
