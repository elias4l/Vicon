----------------------------------------------------------------------------------
-- Test para comprobar el funcionamiento del CMOS MT9V111
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
           JB : inout STD_LOGIC_VECTOR(7 downto 0);
           JC : inout STD_LOGIC_VECTOR(7 downto 0);
           JXADC : inout STD_LOGIC_VECTOR(7 downto 0));

end TOP;

architecture Behavioral of TOP is

--aliases puerto JA
alias CAM_D6: STD_LOGIC is JA(0); --JA1, J1 , -i
alias CAM_XCLK: STD_LOGIC is JA(1); --JA2, L2 , -o
alias CAM_HSYNC: STD_LOGIC is JA(2); --JA3, J2 , -i
alias CAM_SDA: STD_LOGIC is JA(3); --JA4, G2 , -io
alias CAM_PCLK: STD_LOGIC is JA(4); --JA7, H1 , -i
alias CAM_D7: STD_LOGIC is JA(5); --JA8, K2 , -i
alias CAM_VSYNC: STD_LOGIC is JA(6); --JA9, H2 , -i
alias CAM_SCL: STD_LOGIC is JA(7); --JA10, G3 , -io

--aliases puerto JB y JC
--alias FT245_D: STD_LOGIC_VECTOR(7 downto 0) is JB; -- -o
--alias FT245_RXEn : STD_LOGIC is JC(0); --JC1, K17 , -?
--alias FT245_RDn  : STD_LOGIC is JC(1); --JC2, M18 , -?
--alias FT245_SIWUn  : STD_LOGIC is JC(2); --JC3, N17 , -o
--alias FT245_OEn  : STD_LOGIC is JC(3); --JC4, P18 , -o
--alias FT245_TXEn : STD_LOGIC is JC(4); --JC7, L17 , -i
--alias FT245_WRn  : STD_LOGIC is JC(5); --JC8, M19 , -o
--alias CLOKOUT  : STD_LOGIC is JC(6); --JC9, P17 , -o
--alias PWRSAVn  : STD_LOGIC is JC(7); --JC10, R18 , -?

--aliases puerto JXADC
alias CAM_D0: STD_LOGIC is JXADC(1); --JXAC2, L3 , -i
alias CAM_D2: STD_LOGIC is JXADC(2); --JXAC3, M2 , -i
alias CAM_D4: STD_LOGIC is JXADC(3); --JXAC4, N2 , -i
alias CAM_D1: STD_LOGIC is JXADC(5); --JXAC8, K3 , -i
alias CAM_D3: STD_LOGIC is JXADC(6); --JXAC7, M1 , -i
alias CAM_D5: STD_LOGIC is JXADC(7); --JXAC8, P1 , -i



--datos del CMOS
signal CAM_DATA  : STD_LOGIC_VECTOR(7 downto 0);

--señales usadas en camMMCM
signal CAM_CLK1  : STD_LOGIC;
signal CAM_CLK2  : STD_LOGIC;
signal CAM_CLK_locked  : STD_LOGIC;

--crear tick con flanco de subida de CAM_PCLK
signal  CAM_PCLK_edge  : STD_LOGIC;

signal  RST  : STD_LOGIC;

signal cam_div : unsigned(23 downto 0) := (others => '0'); --borrar, LED15


--señales usadas en FT245_IF, lado FPGA
--signal UserDataIn  : STD_LOGIC_VECTOR(7 downto 0);
--signal User_wr_en  : STD_LOGIC;
--signal User_rdy_flag  : STD_LOGIC;
--signal MRST   : STD_LOGIC := '0';
--seales usadas en FT245_IF, lado conector
--signal FT245_D_s   : STD_LOGIC_VECTOR(7 downto 0);
--signal FT245_TXEn_s   : STD_LOGIC;
--signal FT245_WRn_s    : STD_LOGIC;

--signal cont_dato  : unsigned(7 downto 0) := (others => '0');


begin

    --datos de la camara
    CAM_DATA <= CAM_D7 & CAM_D6 & CAM_D5 & CAM_D4 & CAM_D3 & CAM_D2 & CAM_D1 & CAM_D0;
    
    RST <= '0';

    --reloj de 12Mhz para CAM_XCLK
    camMMCM: entity WORK.clk_wiz_0
    port map (
        clk_in1 => CLK,
        reset => RST,
        clk_out1 => CAM_CLK1,
        clk_out2 => CAM_CLK2,
        locked => CAM_CLK_locked
    );
    CAM_XCLK <= CAM_CLK2;

    --señales de entrada no usadas en JA
    CAM_SDA <= 'Z'; -- SDA
    CAM_SCL <= 'Z'; -- SCL
    --señales de entrada no usadas en JXAC
    JXADC(0) <= '1'; -- JXAC1
    JXADC(4) <= 'Z'; -- JXAC7

    --crear tick con flanco de subida de CAM_PCLK
    edge_CAM_PCLK: entity work.edge_detect
    port map (
        clk   => CLK,
        reset => RST,
        level => CAM_PCLK,
        tick  => CAM_PCLK_edge
    );
--  User_wr_en <= CAM_PCLK_edge;
       
    --borrar, LED 15 muestra el reloj 12MHz
    process(CAM_CLK2)
    begin
        if rising_edge(CAM_CLK2) then
            cam_div <= cam_div + 1;
        end if;
    end process;
    LED(15) <= cam_div(22);

    led(7 downto 0) <= CAM_DATA;
    led(8)          <= CAM_HSYNC;
    led(9)          <= CAM_VSYNC;
    led(10)         <= CAM_PCLK;
    led(14)         <= CAM_CLK_locked;    


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

--    UserDataIn <= std_logic_vector(cont_dato);


-- ===============================
--    INSTANCE TEMPLATE
-- ===============================
--    FT245_inst: entity work.FT245_IF
--    port map (
--       clk     => CLK, -- i
--        reset   => MRST, -- i
    
    -- User IO ---------------------------
--        DIN     => UserDataIn,     -- i[7:0]
--        wr_en   => User_wr_en,     -- i
--        ready   => User_rdy_flag,  -- o
    
    -- FT245-like interface --------------
--        TXEn    => FT245_TXEn_s,     -- i
--        WRn     => FT245_WRn_s,      -- o
--        DATA    => FT245_D_s         -- o[7:0]
--    );

    -- conexionado del FT245_IF con el conector JB y JC.
    --FT245_D <= FT245_D_s;
--    FT245_D(0) <= FT245_D_s(0);
--    FT245_D(1) <= FT245_D_s(2);
--    FT245_D(2) <= FT245_D_s(4);
--    FT245_D(3) <= FT245_D_s(6);
--    FT245_D(4) <= FT245_D_s(1);
--    FT245_D(5) <= FT245_D_s(3);
--    FT245_D(6) <= FT245_D_s(5);
--    FT245_D(7) <= FT245_D_s(7);
--    FT245_WRn <= FT245_WRn_s;
--    FT245_TXEn_s <= FT245_TXEn;
--    FT245_RDn <= '1';  -- no usados
--    FT245_SIWUn <= '1';  -- no usados
--    FT245_OEn <= '1';  -- no usados
--    PWRSAVn <= '0';  -- no usados
   
end Behavioral;
