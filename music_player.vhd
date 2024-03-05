----------------------------------------------------------------------------------
-- Company: Chalmers
-- Engineer: Pengfei 
-- 
-- Create Date: 2024/03/04 12:18:27
-- Design Name: 
-- Module Name: music_player - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 

-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity music_player is
  Port (    clk:        in std_logic;
            rst:        in std_logic;
            enable:    in std_logic;
            AUD_PWM:    out std_logic;
            AUD_SD:     out std_logic   
   );
end music_player;

architecture Behavioral of music_player is

component  tone_generator is
    Port ( clk : in STD_LOGIC;
           volume : in integer;
           tone_index : in integer;
           AUD_PWM : out STD_LOGIC;
           AUD_SD : out STD_LOGIC);
end component;

COMPONENT ila_0

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
	probe3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
);
END COMPONENT  ;

type state_type is (idle,
                      fetch_note, 
                      play_note 
                      );
type note_table is array (integer range <>) of integer;

--constant  T_M : integer := 10000;
-- tempo in bpm                     
constant TEMPO  : integer := 120;
-- number of clk cycles for 1/4 beat
constant QUATER_BEAT : integer := integer(60*25e6/TEMPO);
-- silence cycles after each note
constant SILENT_GAP:     integer := 6e6;
-- number of notes in the music segment
constant TOTAL_NOTE_NUM : integer := 42;
                      
signal my_note_table : note_table(0 to TOTAL_NOTE_NUM-1);
signal my_len_table  : note_table(0 to TOTAL_NOTE_NUM-1);

signal tone_index    : integer range 0 to 31 := 15;
signal volume       : integer range 0 to 10  :=10;
signal m_Key        : integer range 0 to 10 := 8;

signal current_state : state_type;
signal next_state : state_type;
-- the note fetched , offset by 11. index 0 means silence
signal tone_index_buff: integer range 0 to 31 :=0;
-- the duration of the note fetched
-- 1 means quater beat, 2 means half beat, 4 means 1 beat.
signal  tone_len_buff:  integer range 0 to 8  := 4;  
-- the note index to loop within the music segment 46 notes in total
signal note_Index : integer range 0 to  TOTAL_NOTE_NUM-1 :=0;
-- counter for note length control
signal beat_cnt : integer range 0 to  8*QUATER_BEAT -1 :=0;
-- multiplier counter 
--signal m_cnt : integer range 0 to T_M -1 := 0;
-- flag to fectch next note
signal next_note: std_logic;

-- probe signals
signal enable_prob: std_logic_vector(0 downto 0);
signal cur_state_prob: std_logic_vector(1 downto 0);
signal tone_prob:   std_logic_vector(4 downto 0);
signal note_len_prob: std_logic_vector(3 downto 0);

begin

   tone_gen_inst: component  tone_generator
        port map(
                clk => clk,
                AUD_PWM => AUD_PWM,
                AUD_SD => AUD_SD,
                volume => volume,
                tone_index => tone_index
        );
        
 prob_inst : ila_0
PORT MAP (
	clk => clk,

	probe0 => enable_prob, 
	probe1 => tone_prob,
	probe2 => cur_state_prob,
	probe3 => note_len_prob
);       
        
  my_note_table(0) <=   0; 
  my_note_table(1) <=   19;
  my_note_table(2) <=   19;
  my_note_table(3) <=   18;
  my_note_table(4) <=   17;
  my_note_table(5) <=   15;
  
  my_note_table(6) <=   15;
  my_note_table(7) <=   15;
  my_note_table(8) <=   17;
  my_note_table(9) <=   18;
  my_note_table(10) <=  17;
        
  my_note_table(11) <=  0; 
  my_note_table(12) <=  19;
  my_note_table(13) <=  19;
  my_note_table(14) <=  18;
  my_note_table(15) <=  17;      
  my_note_table(16) <=  15;
  
  my_note_table(17) <=  15;
  my_note_table(18) <=  15;  
  my_note_table(19) <=  17;
  my_note_table(20) <=  18;  
  my_note_table(21) <=  17;
  
  my_note_table(22) <=  0;
  my_note_table(23) <=  7;
  my_note_table(24) <=  10;
  my_note_table(25) <=  10; 
  my_note_table(26) <=  11;
  my_note_table(27) <=  13;
  
  my_note_table(28) <=  13;
  my_note_table(29) <=  12;
  my_note_table(30) <=  11; 
  my_note_table(31) <=  11;
  my_note_table(32) <=  10;
  
  my_note_table(33) <=  10;
  my_note_table(34) <=  7;
  my_note_table(35) <=  10; 
  my_note_table(36) <=  11;
  my_note_table(37) <=  11;
  
  my_note_table(38) <=  11;
  my_note_table(39) <=  0;
  my_note_table(40) <=  0;    
  my_note_table(41) <=  0;
  
--  my_note_table(42) <=  12;
--  my_note_table(43) <=  15;
--  my_note_table(44) <=  14;
--  my_note_table(45) <=  12;
--  my_note_table(46) <=  11;
--  my_note_table(47) <=  10;
  
  my_len_table(0) <=    4  ;
  my_len_table(1) <=    4  ;
  my_len_table(2) <=    2  ;
  my_len_table(3) <=    2  ;
  my_len_table(4) <=    2  ;
  my_len_table(5) <=    2  ;
  
  my_len_table(6) <=    2  ;
  my_len_table(7) <=    4  ;
  my_len_table(8) <=    2  ;
  my_len_table(9) <=    4  ;
  my_len_table(10) <=   4  ;
  
  my_len_table(11) <=   4  ;
  my_len_table(12) <=   4  ;
  my_len_table(13) <=   2  ;
  my_len_table(14) <=   2  ;
  my_len_table(15) <=   2  ;
  my_len_table(16) <=   2  ;
  
  my_len_table(17) <=   2  ;
  my_len_table(18) <=   4  ;
  my_len_table(19) <=   2  ;
  my_len_table(20) <=   4  ;
  my_len_table(21) <=   4  ;
  
  my_len_table(22) <=   4  ;
  my_len_table(23) <=   2  ;
  my_len_table(24) <=   2  ;
  my_len_table(25) <=   2  ;
  my_len_table(26) <=   4  ;
  my_len_table(27) <=   2  ;
  
  my_len_table(28) <=   4  ;
  my_len_table(29) <=   2  ;
  my_len_table(30) <=   2  ;
  my_len_table(31) <=   2  ;
  my_len_table(32) <=   6  ;
  
  my_len_table(33) <=   2  ;
  my_len_table(34) <=   4  ;
  my_len_table(35) <=   4  ;
  my_len_table(36) <=   4  ;
  my_len_table(37) <=   2  ;
  
  my_len_table(38) <=   2  ;
  my_len_table(39) <=   4  ;
  my_len_table(40) <=   4  ;
  my_len_table(41) <=   4  ;
  
--  my_len_table(42) <=   1  ;
--  my_len_table(43) <=   2  ;
--  my_len_table(44) <=   2  ;
--  my_len_table(45) <=   2  ;
--  my_len_table(46) <=   1  ;
--  my_len_table(47) <=   1  ;
  
  -- debug probe
  tone_prob <= std_logic_vector(TO_UNSIGNED(tone_index_buff, tone_prob'length));
  enable_prob(0) <= enable;
  note_len_prob <= std_logic_vector(TO_UNSIGNED(tone_len_buff, note_len_prob'length));
  
  -- pass the tone index to tone generator
  tone_index <= tone_index_buff;        
          
   -- FSM state register
  state_change_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        current_state <= idle;
      else
        current_state <= next_state;
      end if;
    end if;
  end process state_change_proc;   
        
  next_state_proc: process(enable, next_note)
  begin
        next_state <= current_state;
 
        case current_state is
          when idle =>             
            if enable = '1' then                    -- start the FSM
               next_state <= fetch_note;
            end if;
            -- debug probe
            cur_state_prob <= "00";
          when fetch_note =>
            next_state <= play_note;
            -- debug probe
            cur_state_prob <= "01";
          when play_note =>
            if enable = '1' then                    -- continue to play
               if next_note = '1' then 
                next_state <= fetch_note;
               end if;
            else
               next_state <= idle;
            end if;
            -- debug probe
            cur_state_prob <= "10";
        end case;
    end process;      
    
    note_ctrl: process(clk)
    begin
        if falling_edge(clk) then
            case current_state is
              when idle =>             
                next_note <= '0';         -- clear the flag
                note_Index <= 0;          -- reset the index
                tone_index_buff <= 0;     -- reset the tone index
                tone_len_buff <= 0;       -- reset the tone length
                
              when fetch_note =>
                -- fetch the note and the length from the lookup table
                -- accoring to the note index
                if my_note_table(note_Index) = 0 then
                    tone_index_buff <= 0;       -- 0 means silence so don't bias with key
                else
                    tone_index_buff <= my_note_table(note_Index) + m_Key;
                end if;
                tone_len_buff <= my_len_table(note_Index);   
                      
              when play_note =>
                -- update the beat cnt to control the tone length
                if beat_cnt < tone_len_buff * QUATER_BEAT -1 then
                    beat_cnt <= beat_cnt + 1;
                else
                    beat_cnt <= 0;
                    
                    -- set the flag to indicate moving to next note
                    next_note <= '1'; 
                    -- increase the note index
                    if note_Index < TOTAL_NOTE_NUM -1 then
                        note_Index <= note_Index + 1 ;
                    else
                        note_Index <= 0;
                    end if;
                    
                end if;
                -- make the silence gap at the end of each note
                if beat_cnt > tone_len_buff * QUATER_BEAT - SILENT_GAP then
                    tone_index_buff <= 0;
                end if;
                        
            end case;
        end if;
    end process; 
    
   


end Behavioral;
