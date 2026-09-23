--------------------------------------------------------------------------------
-- Archivo      : top_spi.vhd
-- Proyecto     : Taller 1 - Comunicacion SPI en FPGA DE1 - Loopback Maestro-Esclavo
-- Parametros del grupo (semilla S = 64):
--   Modo SPI        = 0  (CPOL = 0, CPHA = 0)
--   CLKS_PER_HALF    = 25   -> f_SCLK = 1 MHz
--   Orden de bits    = MSB primero
--   ID_ESCLAVO       = 0x9A
-- Descripcion  : Instancia el maestro, el esclavo, el antirrebote y los cuatro
--                decodificadores de 7 segmentos. No contiene logica propia mas
--                alla de las conexiones. El lazo MOSI/MISO/SCLK/SS_N se cierra
--                EXTERNAMENTE con cuatro cables jumper en el header GPIO JP1
--                segun la Tabla 2 del taller (no dentro de este archivo).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spitaller is
    port (
        CLOCK_50 : in  std_logic;
        SW       : in  std_logic_vector(7 downto 0);
        KEY      : in  std_logic_vector(0 downto 0);

        GPIO_0   : inout std_logic_vector(7 downto 0);

        HEX0, HEX1, HEX2, HEX3 : out std_logic_vector(6 downto 0);
        LEDR     : out std_logic_vector(0 downto 0);
        LEDG     : out std_logic_vector(0 downto 0)
    );
end entity spi-taller;

architecture rtl of spi-taller is

    -- Parametros de diseno del grupo (S = 64), unico lugar donde se declaran
    constant DATA_WIDTH    : positive   := 8;
    constant CLKS_PER_HALF : positive   := 25;
    constant CPOL          : std_logic  := '0';
    constant CPHA          : std_logic  := '0';
    constant MSB_FIRST     : boolean    := true;
    constant ID_ESCLAVO    : std_logic_vector(7 downto 0) := x"9A";

    signal n_rst   : std_logic := '1';  -- Sin pulsador de reset dedicado: en alto permanente

    signal start_pulse : std_logic;

    signal m_sclk, m_mosi, m_ss_n : std_logic;
    signal m_miso                  : std_logic;
    signal m_busy, m_done          : std_logic;
    signal m_rx_data               : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal s_miso                  : std_logic;
    signal s_valid                 : std_logic;
    signal s_rx_data               : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Registros de displays: se actualizan solo cuando el dato es valido
    signal disp_maestro_id  : std_logic_vector(7 downto 0) := (others => '0'); -- HEX3-HEX2
    signal disp_esclavo_dat : std_logic_vector(7 downto 0) := (others => '0'); -- HEX1-HEX0

begin

    ----------------------------------------------------------------
    -- Antirrebote de KEY[0] -> pulso de inicio de una transaccion
    ----------------------------------------------------------------
    u_antirrebote : entity work.antirrebote
        generic map (
            F_RELOJ    => 50_000_000,
            T_ANTIRREB => 10_000
        )
        port map (
            clk   => CLOCK_50,
            n_rst => n_rst,
            key_n => KEY(0),
            pulso => start_pulse
        );

    ----------------------------------------------------------------
    -- Maestro SPI
    ----------------------------------------------------------------
    u_master : entity work.spi_master
        generic map (
            DATA_WIDTH    => DATA_WIDTH,
            CLKS_PER_HALF => CLKS_PER_HALF,
            CPOL          => CPOL,
            CPHA          => CPHA,
            MSB_FIRST     => MSB_FIRST
        )
        port map (
            clk     => CLOCK_50,
            n_rst   => n_rst,
            start   => start_pulse,
            tx_data => SW,

            sclk    => m_sclk,
            mosi    => m_mosi,
            ss_n    => m_ss_n,
            miso    => m_miso,

            rx_data => m_rx_data,
            busy    => m_busy,
            done    => m_done
        );

    ----------------------------------------------------------------
    -- Esclavo SPI
    ----------------------------------------------------------------
    u_slave : entity work.spi_slave
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            CPOL       => CPOL,
            CPHA       => CPHA,
            MSB_FIRST  => MSB_FIRST,
            ID_ESCLAVO => ID_ESCLAVO
        )
        port map (
            clk     => CLOCK_50,
            n_rst   => n_rst,

            sclk_i  => GPIO_0(1),
            mosi_i  => GPIO_0(3),
            ss_n_i  => GPIO_0(7),
            miso_o  => s_miso,

            rx_data => s_rx_data,
            valid   => s_valid
        );

    ----------------------------------------------------------------
    -- Conexion del maestro y el esclavo al puerto GPIO (Tabla 2)
    -- SCLK: maestro->GPIO_0[0] (salida), esclavo<-GPIO_0[1] (entrada)
    -- MOSI: maestro->GPIO_0[2] (salida), esclavo<-GPIO_0[3] (entrada)
    -- MISO: esclavo->GPIO_0[4] (salida), maestro<-GPIO_0[5] (entrada)
    -- SS_N : maestro->GPIO_0[6] (salida), esclavo<-GPIO_0[7] (entrada)
    -- El lazo fisico entre estos pines se cierra con los 4 cables jumper externos.
    ----------------------------------------------------------------
    GPIO_0(0) <= m_sclk;
    GPIO_0(2) <= m_mosi;
    GPIO_0(6) <= m_ss_n;
    GPIO_0(4) <= s_miso;

    GPIO_0(1) <= 'Z';
    GPIO_0(3) <= 'Z';
    GPIO_0(5) <= 'Z';
    GPIO_0(7) <= 'Z';

    m_miso <= GPIO_0(5);

    ----------------------------------------------------------------
    -- Registro de displays: solo se actualizan cuando el dato es valido
    ----------------------------------------------------------------
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if n_rst = '0' then
                disp_maestro_id  <= (others => '0');
                disp_esclavo_dat <= (others => '0');
            else
                if m_done = '1' then
                    disp_maestro_id <= m_rx_data;
                end if;
                if s_valid = '1' then
                    disp_esclavo_dat <= s_rx_data;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Decodificadores de 7 segmentos
    ----------------------------------------------------------------
    u_hex0 : entity work.hex7seg port map (hex_in => disp_esclavo_dat(3 downto 0), seg_n => HEX0);
    u_hex1 : entity work.hex7seg port map (hex_in => disp_esclavo_dat(7 downto 4), seg_n => HEX1);
    u_hex2 : entity work.hex7seg port map (hex_in => disp_maestro_id(3 downto 0),  seg_n => HEX2);
    u_hex3 : entity work.hex7seg port map (hex_in => disp_maestro_id(7 downto 4),  seg_n => HEX3);

    ----------------------------------------------------------------
    -- Indicadores
    ----------------------------------------------------------------
    LEDR(0) <= m_busy;
    LEDG(0) <= not m_ss_n;

end architecture rtl;