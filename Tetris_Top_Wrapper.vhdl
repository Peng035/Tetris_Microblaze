----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/13/2024 03:18:16 PM
-- Design Name: 
-- Module Name: Tetris_Top_Wrapper - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
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

entity Tetris_Top_Wrapper is
  Port ( 
    button_C : in STD_LOGIC;
    button_D : in STD_LOGIC;
    button_L : in STD_LOGIC;
    button_R : in STD_LOGIC;
    button_U : in STD_LOGIC;
    clk : in STD_LOGIC;
    restart_s : in STD_LOGIC;
    rst : in STD_LOGIC;
    h_sync    	: OUT  STD_LOGIC;  --horiztonal sync pulse
    v_sync    	: OUT  STD_LOGIC;  --vertical sync pulse
    data_out     : out std_logic_vector(12-1 downto 0);
    uart_rxd : in STD_LOGIC;
    uart_txd : out STD_LOGIC
  );
end Tetris_Top_Wrapper;

architecture Behavioral of Tetris_Top_Wrapper is

component VGA_Shell is
  port (
	clk 		: in std_logic;
	reset_n 	: in std_logic;
	write_en    : in std_logic;
	h_sync    	: OUT  STD_LOGIC;  --horiztonal sync pulse
    v_sync    	: OUT  STD_LOGIC;  --vertical sync pulse
    	--n_blank   	: OUT  STD_LOGIC;  --direct blacking output to DAC
    	--n_sync    	: OUT  STD_LOGIC; --sync-on-green output to DAC
	data_out     : out std_logic_vector(12-1 downto 0);
	shape_in     : in std_logic_vector(2 downto 0);
	rot_in       : in std_logic_vector(1 downto 0);
	proc_pos:       in std_logic_vector(11 - 1 downto 0);	
	clear_in       : in std_logic
	);
	
end component;

component  Tetris_MicroBlaze_wrapper is
  port (
    GPIO_0_tri_o : out STD_LOGIC_VECTOR ( 23 downto 0 );
    button_C : in STD_LOGIC;
    button_D : in STD_LOGIC;
    button_L : in STD_LOGIC;
    button_R : in STD_LOGIC;
    button_U : in STD_LOGIC;
    clk : in STD_LOGIC;
    restart_s : in STD_LOGIC;
    rst : in STD_LOGIC;
    uart_rxd : in STD_LOGIC;
    uart_txd : out STD_LOGIC
  );
end component ;

signal gpio_buff :std_logic_vector (23 downto 0);
signal rst_n: std_logic ;

begin

MicroBlaze_inst: component Tetris_MicroBlaze_wrapper
    port map(
        clk         =>    clk      ,
        rst         =>    rst      ,
        button_C    =>    button_C ,
        button_D    =>    button_D ,
        button_L    =>    button_L ,
        button_R    =>    button_R ,
        button_U    =>    button_U ,
        uart_rxd    =>    uart_rxd ,
        uart_txd    =>    uart_txd ,
        restart_s   =>    restart_s,
        GPIO_0_tri_o=>    gpio_buff         
    );
    
 rst_n <= not rst;
    
 VGA_Shell_inst: component VGA_Shell
    port map(
        clk 		    => clk,
        reset_n 	    => rst_n,
        write_en        => gpio_buff(23),
        h_sync          => h_sync,
        v_sync          => v_sync,
        data_out        => data_out,
        shape_in        => gpio_buff(15 downto 13),
        rot_in          => gpio_buff(12 downto 11),
        proc_pos        => gpio_buff(10 downto 0),
        clear_in        =>  '0'
    );


end Behavioral;
