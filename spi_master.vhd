--------------------------------------------------------------------------------
-- Archivo      : spi_master.vhd
-- Proyecto     : Taller 1 - Comunicacion SPI en FPGA DE1 - Loopback Maestro-Esclavo
-- Descripcion  : Maestro SPI parametrizado (CPOL, CPHA, orden de bits, divisor
--                de reloj). FSM de reposo / activacion SS_N / transferencia /
--                liberacion. Reset sincrono, un unico dominio de reloj (CLOCK_50).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    generic (
        DATA_WIDTH    : positive := 8;     -- Numero de bits de la palabra
        CLKS_PER_HALF : positive := 25;    -- Ciclos de CLOCK_50 por medio periodo de SCLK
        CPOL          : std_logic := '0';  -- Polaridad de reposo de SCLK
        CPHA          : std_logic := '0';  -- Fase: '0' muestrea en 1er flanco, '1' en el 2do
        MSB_FIRST     : boolean   := true  -- true: MSB primero, false: LSB primero
    );
    port (
        clk      : in  std_logic;
        n_rst    : in  std_logic;                      -- Reset sincrono, activo en bajo
        start    : in  std_logic;                      -- Pulso de un ciclo que inicia la transaccion
        tx_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Dato a enviar (SW[7..0])

        sclk     : out std_logic;
        mosi     : out std_logic;
        ss_n     : out std_logic;
        miso     : in  std_logic;

        rx_data  : out std_logic_vector(DATA_WIDTH-1 downto 0); -- Dato recibido (ID del esclavo)
        busy     : out std_logic;                      -- Activo durante toda la transaccion
        done     : out std_logic                       -- Pulso de un ciclo al finalizar
    );
end entity spi_master;

architecture rtl of spi_master is

    type state_t is (IDLE, SETUP, TRANSFER, HOLD);
    signal state : state_t := IDLE;

    signal half_cnt   : integer range 0 to CLKS_PER_HALF-1 := 0;
    signal edge_cnt    : integer range 0 to 2*DATA_WIDTH := 0;

    signal sclk_r     : std_logic := CPOL;
    signal ss_n_r      : std_logic := '1';
    signal mosi_r      : std_logic := '0';
    signal busy_r      : std_logic := '0';
    signal done_r      : std_logic := '0';

    signal tx_reg      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal rx_reg       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal rx_data_r    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    signal tx_index     : integer range 0 to DATA_WIDTH-1 := 0;
    signal rx_index      : integer range 0 to DATA_WIDTH-1 := 0;
    signal tx_preloaded  : std_logic := '0';

    -- Indice inicial segun el orden de bits configurado
    function idx_inicial return integer is
    begin
        if MSB_FIRST then
            return DATA_WIDTH-1;
        else
            return 0;
        end if;
    end function;

    function idx_siguiente(i : integer) return integer is
    begin
        if MSB_FIRST then
            return i - 1;
        else
            return i + 1;
        end if;
    end function;

begin

    process(clk)
        variable leading : boolean; -- true = flanco que aleja SCLK del reposo (1er flanco del periodo)
    begin
        if rising_edge(clk) then

            if n_rst = '0' then

                state        <= IDLE;
                half_cnt     <= 0;
                edge_cnt     <= 0;
                sclk_r       <= CPOL;
                ss_n_r       <= '1';
                mosi_r       <= '0';
                busy_r       <= '0';
                done_r       <= '0';
                tx_reg       <= (others => '0');
                rx_reg       <= (others => '0');
                rx_data_r    <= (others => '0');
                tx_index     <= idx_inicial;
                rx_index     <= idx_inicial;
                tx_preloaded <= '0';

            else

                done_r <= '0';

                case state is

                    when IDLE =>
                        sclk_r   <= CPOL;
                        ss_n_r   <= '1';
                        busy_r   <= '0';
                        half_cnt <= 0;
                        edge_cnt <= 0;

                        if start = '1' then
                            tx_reg   <= tx_data;
                            tx_index <= idx_inicial;
                            rx_index <= idx_inicial;
                            ss_n_r   <= '0';
                            busy_r   <= '1';
                            half_cnt <= 0;

                            if CPHA = '0' then
                                -- El dato debe estar listo antes del primer flanco (muestreo)
                                mosi_r       <= tx_data(idx_inicial);
                                tx_preloaded <= '1';
                            else
                                mosi_r       <= '0';
                                tx_preloaded <= '0';
                            end if;

                            state <= SETUP;
                        end if;

                    when SETUP =>
                        -- Espera al menos medio periodo de SCLK antes del primer flanco
                        if half_cnt = CLKS_PER_HALF-1 then
                            half_cnt <= 0;
                            edge_cnt <= 0;
                            state    <= TRANSFER;
                        else
                            half_cnt <= half_cnt + 1;
                        end if;

                    when TRANSFER =>
                        if half_cnt = CLKS_PER_HALF-1 then
                            half_cnt <= 0;
                            sclk_r   <= not sclk_r;
                            edge_cnt <= edge_cnt + 1;

                            -- edge_cnt par (0,2,4..) => flanco que aleja SCLK del reposo (1er flanco)
                            leading := (edge_cnt mod 2 = 0);

                            if (leading and CPHA = '0') or (not leading and CPHA = '1') then
                                -- Flanco de muestreo
                                rx_reg(rx_index) <= miso;
                                rx_index         <= idx_siguiente(rx_index);
                            else
                                -- Flanco de cambio de dato
                                if tx_preloaded = '1' then
                                    tx_index <= idx_siguiente(tx_index);
                                    mosi_r   <= tx_reg(idx_siguiente(tx_index));
                                else
                                    mosi_r       <= tx_reg(tx_index);
                                    tx_preloaded <= '1';
                                end if;
                            end if;

                            if edge_cnt = 2*DATA_WIDTH - 1 then
                                state <= HOLD;
                            end if;
                        else
                            half_cnt <= half_cnt + 1;
                        end if;

                    when HOLD =>
                        -- Mantiene SS_N activo medio periodo despues del ultimo flanco
                        if half_cnt = CLKS_PER_HALF-1 then
                            ss_n_r    <= '1';
                            busy_r    <= '0';
                            done_r    <= '1';
                            rx_data_r <= rx_reg;
                            state     <= IDLE;
                        else
                            half_cnt <= half_cnt + 1;
                        end if;

                end case;

            end if;

        end if;
    end process;

    sclk    <= sclk_r;
    mosi    <= mosi_r;
    ss_n    <= ss_n_r;
    busy    <= busy_r;
    done    <= done_r;
    rx_data <= rx_data_r;

end architecture rtl;