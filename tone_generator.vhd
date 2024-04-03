
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity tone_generator is
    Port ( clk : in STD_LOGIC;
           vol_up : in std_logic;
           vol_down: in std_logic;
           mute :   in std_logic;
           tone_index : in std_logic_vector(5 downto 0);     -- shifted by 11 tone index
           AUD_PWM : out STD_LOGIC;
           AUD_SD : out STD_LOGIC);
end tone_generator;

architecture Behavioral of tone_generator is

constant MAX_VOLUME : integer := 600;

-- the counter to generate correct freq
signal  cnt : integer range 0 to 5e5;
signal  TOTAL_CNT : integer range 0 to 5e5;
signal  PULSE_CNT : integer range 0 to 5e5;
-- temp buffere to store the value for PWM
signal temp: std_logic;
-- counter to set volume
--signal vol_buff: integer range 0 to 10 :=6;
signal volume_reg: integer range 0 to 20 := 4;
signal mute_reg: integer range 0 to 1 :=1;

signal vol_up_reg1: std_logic;
signal vol_up_reg2: std_logic;
signal vol_down_reg1: std_logic;
signal vol_down_reg2: std_logic;
signal vol_up_edge: std_logic;
signal vol_down_edge: std_logic;

signal tone_index_reg: std_logic_vector(5 downto 0); 

begin
  
 edge_proc: process(clk)
  begin
    if rising_edge(clk) then
        vol_up_reg2 <= vol_up_reg1;  -- Shift the previous value
        vol_up_reg1 <= vol_up;
        
        vol_down_reg2 <= vol_down_reg1;  -- Shift the previous value
        vol_down_reg1 <= vol_down;
        
        tone_index_reg <= tone_index;  -- Update the tone index
    end if;
  end process;

  vol_up_edge <=  vol_up_reg1 and (not vol_up_reg2);    -- Detect rising edge of vol_up
  vol_down_edge <=  vol_down_reg1 and (not vol_down_reg2);    -- Detect rising edge of vol_down
  
  
 input_proc: process(clk)
    begin
        if rising_edge(clk) then
            case tone_index_reg is 
                        when "000000"     =>   TOTAL_CNT <= 0 ;
                        when "000001"     =>   TOTAL_CNT <= 20325 ;                
                        when "000010"     =>   TOTAL_CNT <= 19157 ;                
                        when "000011"     =>   TOTAL_CNT <= 18050 ;                
                        when "000100"     =>   TOTAL_CNT <= 17064 ;                
                        when "000101"     =>   TOTAL_CNT <= 16077 ;                
                        when "000110"     =>   TOTAL_CNT <= 15197 ;                
                        when "000111"     =>   TOTAL_CNT <= 14326 ;                
                        when "001000"     =>   TOTAL_CNT <= 13550 ;                
                        when "001001"     =>   TOTAL_CNT <= 12787 ;                
                        when "001010"     =>   TOTAL_CNT <= 12048 ;                
                        when "001011"     =>   TOTAL_CNT <= 11363 ;     -- 440HZ   
                        when "001100"     =>   TOTAL_CNT <= 10729 ;                
                        when "001101"     =>   TOTAL_CNT <= 10141 ;                
                        when "001110"     =>   TOTAL_CNT <= 9560  ;              
                        when "001111"     =>   TOTAL_CNT <= 9025  ;              
                        when "010000"     =>   TOTAL_CNT <= 8517  ;              
                        when "010001"     =>   TOTAL_CNT <= 8038  ;              
                        when "010010"     =>   TOTAL_CNT <= 7587  ;              
                        when "010011"     =>   TOTAL_CNT <= 7163  ;              
                        when "010100"     =>   TOTAL_CNT <= 6765  ;              
                        when "010101"     =>   TOTAL_CNT <= 6385  ;              
                        when "010110"     =>   TOTAL_CNT <= 6024  ;              
                        when "010111"     =>   TOTAL_CNT <= 5681  ;              
                        when "011000"     =>   TOTAL_CNT <= 5364  ;              
                        when "011001"     =>   TOTAL_CNT <= 5065  ;              
                        when "011010"     =>   TOTAL_CNT <= 4780  ;              
                        when "011011"     =>   TOTAL_CNT <= 4512  ;              
                        when "011100"     =>   TOTAL_CNT <= 4258  ;              
                        when "011101"     =>   TOTAL_CNT <= 4019  ;              
                        when "011110"     =>   TOTAL_CNT <= 3793  ;              
                        when "011111"     =>   TOTAL_CNT <= 3581  ;              
                        when others        =>   TOTAL_CNT <= 0;
                    end case; 
       end if;
    end process;
   
    
GEN_PWM_CNT_PROC:  process(clk)
    begin
        if rising_edge (clk) then               
            if  cnt < 2 * TOTAL_CNT - 1 then
                cnt <= cnt + 1;
            else
                cnt <= 0;
            end if; 
        end if;
    end process GEN_PWM_CNT_PROC;
  

proc_1: process(clk)
    begin       
        if rising_edge(clk) then 
            if (vol_up_edge = '1') then
                if volume_reg < 32  then  -- Ensure volume does not exceed MAX_VOLUME
                    volume_reg <= volume_reg + 1;
                end if;
             end if;
             if (vol_down_edge = '1') then
                if volume_reg > 0 then
                    volume_reg <= volume_reg - 1;
                end if;
             end if;       
        end if;
    end process;
    
   
    -- Change the volume
     PULSE_CNT <= 2 * TOTAL_CNT * volume_reg  / MAX_VOLUME;    

proc_2: process(clk)
  begin
    if rising_edge(clk) then          
         if (cnt < PULSE_CNT ) then
            temp <= '1' ;
         else
            temp <= '0';
         end if;
    end if;     
  end process;  
    
OUTPUT_PORC: process(clk)
    begin     
        if falling_edge(clk) then
            if (mute = '1') then
               AUD_PWM <= 'Z';  -- Mute the output
            else
                if temp = '1' then
                    AUD_PWM <= 'Z';  -- Mute the output during the pulse
               else 
                   AUD_PWM <= '0';  -- Output the pulse
               end if;
            end if;       
        end if;
   end process OUTPUT_PORC;
       
-- Enable the mono audio output
AUD_SD <= '1';

end Behavioral;