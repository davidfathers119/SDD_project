--------------------------------------------------------------------------------
-- Title       : VHDL Template
-- Project     : 
-- File        : template.vhd
-- Author      : 
-- Company     : 
-- Created     : 2026-01-25
-- Last update : 2026-01-25
-- Description : VHDL 程式模板
--------------------------------------------------------------------------------
-- Revision History:
-- Date        Version  Author  Description
-- 2026-01-25  1.0              Initial version
--------------------------------------------------------------------------------

-- Library 宣告
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity 定義
entity template is
    generic (
        DATA_WIDTH : integer := 8          -- 資料寬度
    );
    port (
        -- 時鐘與重置訊號
        clk        : in  std_logic;        -- 系統時鐘
        rst_n      : in  std_logic;        -- 低電位重置
        
        -- 輸入訊號
        data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        enable     : in  std_logic;
        
        -- 輸出訊號
        data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid      : out std_logic
    );
end entity template;

-- Architecture 實作
architecture rtl of template is
    
    -- 內部訊號宣告
    signal data_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- 常數宣告
    constant INIT_VALUE : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    
begin
    
    -- 同步處理程序
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            -- 非同步重置
            data_reg <= INIT_VALUE;
            valid    <= '0';
            
        elsif rising_edge(clk) then
            -- 同步邏輯
            if enable = '1' then
                data_reg <= data_in;
                valid    <= '1';
            else
                valid    <= '0';
            end if;
            
        end if;
    end process;
    
    -- 組合邏輯輸出
    data_out <= data_reg;
    
end architecture rtl;
