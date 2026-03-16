library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- 先提供可綜合的 stub：方便先把 RS-232 端到端流程跑通。
-- 後續再把此檔替換成真正的 256-point FFT core。

entity fft_core_stub is
    generic (
        FFT_SIZE   : integer := 256;
        DATA_WIDTH : integer := 16
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;

        start         : in  std_logic;
        in_re         : in  signed(DATA_WIDTH-1 downto 0);
        in_im         : in  signed(DATA_WIDTH-1 downto 0);
        in_valid      : in  std_logic;

        out_re        : out signed(DATA_WIDTH-1 downto 0);
        out_im        : out signed(DATA_WIDTH-1 downto 0);
        out_valid     : out std_logic;

        busy          : out std_logic;
        done          : out std_logic
    );
end fft_core_stub;

architecture rtl of fft_core_stub is
    type state_t is (IDLE, RUN, ST_OUT);
    signal state : state_t := IDLE;

    type mem_t is array (0 to FFT_SIZE-1) of signed(DATA_WIDTH-1 downto 0);
    signal mem_re, mem_im : mem_t;

    signal wr_idx : integer range 0 to FFT_SIZE := 0;
    signal rd_idx : integer range 0 to FFT_SIZE := 0;

begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            wr_idx <= 0;
            rd_idx <= 0;
            out_re <= (others => '0');
            out_im <= (others => '0');
            out_valid <= '0';
            busy <= '0';
            done <= '0';
        elsif rising_edge(clk) then
            out_valid <= '0';
            done <= '0';

            case state is
                when IDLE =>
                    busy <= '0';
                    wr_idx <= 0;
                    rd_idx <= 0;
                    if start = '1' then
                        state <= RUN;
                        busy <= '1';
                    end if;

                when RUN =>
                    -- 只是把輸入存起來
                    if in_valid = '1' then
                        mem_re(wr_idx) <= in_re;
                        mem_im(wr_idx) <= in_im;
                        if wr_idx = FFT_SIZE-1 then
                            state <= ST_OUT;
                            rd_idx <= 0;
                        else
                            wr_idx <= wr_idx + 1;
                        end if;
                    end if;

                when ST_OUT =>
                    -- 直接把資料原樣吐回（代表 FFT 結果尚未實作）
                    out_re <= mem_re(rd_idx);
                    out_im <= mem_im(rd_idx);
                    out_valid <= '1';
                    if rd_idx = FFT_SIZE-1 then
                        state <= IDLE;
                        busy <= '0';
                        done <= '1';
                    else
                        rd_idx <= rd_idx + 1;
                    end if;
            end case;
        end if;
    end process;
    end rtl;
