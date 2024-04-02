library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity music_player is
  Port (    clk:        in std_logic;
            rst:        in std_logic;
            enable:    in std_logic;
            mute:       in std_logic;
            vol_up: in std_logic;
            vol_down: in std_logic ;
            AUD_PWM:    out std_logic;
            AUD_SD:     out std_logic   
   );
end music_player;

architecture Behavioral of music_player is

component  tone_generator is
    Port ( clk : in STD_LOGIC;
           vol_up : in std_logic;
           vol_down: in std_logic;
           mute : in std_logic ;
           tone_index : in std_logic_vector(5 downto 0);
           AUD_PWM : out STD_LOGIC;
           AUD_SD : out STD_LOGIC);
end component;


type state_type is (idle,
                      fetch_note, 
                      play_note 
                      );
type note_table is array (integer range <>) of integer;


-- tempo in bpm                     
constant TEMPO  : integer := 120;
-- number of clk cycles for 1/4 beat
constant QUATER_BEAT : integer := integer(60*25e5/TEMPO);
-- silence cycles after each note
constant SILENT_GAP:     integer := 5e5;
-- number of notes in the music segment
constant TOTAL_NOTE_NUM : integer := 32;
                      
signal my_note_table : note_table(0 to TOTAL_NOTE_NUM-1);
signal my_len_table  : note_table(0 to TOTAL_NOTE_NUM-1);

signal tone_index    : std_logic_vector( 5 downto 0);
signal m_Key        : integer range 0 to 10 := 2;

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
                vol_up => vol_up,
                vol_down => vol_down,
                mute => mute,
                tone_index => tone_index
        );
         
        
  my_note_table(0) <=   11; 
  my_note_table(1) <=   13;
  my_note_table(2) <=   15;
  my_note_table(3) <=   11;
  my_note_table(4) <=   11;
  my_note_table(5) <=   13;
  my_note_table(6) <=   15;
  my_note_table(7) <=   11;
  my_note_table(8) <=   15;
  my_note_table(9) <=   16;
  my_note_table(10) <=  18;
  my_note_table(11) <=  15; 
  my_note_table(12) <=  16;
  my_note_table(13) <=  18;
  my_note_table(14) <=  18;
  my_note_table(15) <=  20;      
  my_note_table(16) <=  18;
  my_note_table(17) <=  16;
  my_note_table(18) <=  15;  
  my_note_table(19) <=  11;
  my_note_table(20) <=  18;  
  my_note_table(21) <=  20;  
  my_note_table(22) <=  18;
  my_note_table(23) <=  16;
  my_note_table(24) <=  15;
  my_note_table(25) <=  11; 
  my_note_table(26) <=  11;
  my_note_table(27) <=  6;
  my_note_table(28) <=  11;  
  my_note_table(29) <=  11;
  my_note_table(30) <=  6; 
  my_note_table(31) <=  11;
--  my_note_table(32) <=  10;  
--  my_note_table(33) <=  10;
--  my_note_table(34) <=  7;
--  my_note_table(35) <=  10; 
--  my_note_table(36) <=  11;
--  my_note_table(37) <=  11;  
--  my_note_table(38) <=  11;
--  my_note_table(39) <=  0;
--  my_note_table(40) <=  0;    
--  my_note_table(41) <=  0;  
--  my_note_table(42) <=  12;
--  my_note_table(43) <=  15;
--  my_note_table(44) <=  14;
--  my_note_table(45) <=  12;
--  my_note_table(46) <=  11;
--  my_note_table(47) <=  10;
  
  my_len_table(0) <=    2  ;
  my_len_table(1) <=    2  ;
  my_len_table(2) <=    2  ;
  my_len_table(3) <=    2  ;
  my_len_table(4) <=    2  ;
  my_len_table(5) <=    2  ;
  my_len_table(6) <=    2  ;
  my_len_table(7) <=    2  ;
  my_len_table(8) <=    2  ;
  my_len_table(9) <=    2  ;
  my_len_table(10) <=   4  ;  
  my_len_table(11) <=   2  ;
  my_len_table(12) <=   2  ;
  my_len_table(13) <=   4  ;
  my_len_table(14) <=   1  ;
  my_len_table(15) <=   1  ;
  my_len_table(16) <=   1  ;  
  my_len_table(17) <=   1  ;
  my_len_table(18) <=   2  ;
  my_len_table(19) <=   2  ;
  my_len_table(20) <=   1  ;
  my_len_table(21) <=   1  ;  
  my_len_table(22) <=   1  ;
  my_len_table(23) <=   1  ;
  my_len_table(24) <=   2  ;
  my_len_table(25) <=   2  ;
  my_len_table(26) <=   2  ;
  my_len_table(27) <=   2  ;  
  my_len_table(28) <=   4  ;
  my_len_table(29) <=   2  ;
  my_len_table(30) <=   2  ;
  my_len_table(31) <=   4  ;
--  my_len_table(32) <=   6  ;  
--  my_len_table(33) <=   2  ;
--  my_len_table(34) <=   4  ;
--  my_len_table(35) <=   4  ;
--  my_len_table(36) <=   4  ;
--  my_len_table(37) <=   2  ;  
--  my_len_table(38) <=   2  ;
--  my_len_table(39) <=   4  ;
--  my_len_table(40) <=   4  ;
--  my_len_table(41) <=   4  ;  
--  my_len_table(42) <=   1  ;
--  my_len_table(43) <=   2  ;
--  my_len_table(44) <=   2  ;
--  my_len_table(45) <=   2  ;
--  my_len_table(46) <=   1  ;
--  my_len_table(47) <=   1  ;
  
  
  -- pass the tone index to tone generator
  tone_index <= std_logic_vector(to_unsigned(tone_index_buff, tone_index'length));      
          
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
        
  next_state_proc: process(enable, next_note, current_state)
  begin
        next_state <= current_state;
 
        case current_state is
          when idle =>             
            if enable = '1' then                    -- start the FSM
               next_state <= fetch_note;
            end if;

          when fetch_note =>
            next_state <= play_note;

          when play_note =>
            if enable = '1' then                    -- continue to play
               if next_note = '1' then 
                next_state <= fetch_note;
               end if;
            else
               next_state <= idle;
            end if;

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
                next_note <= '0';  
                      
              when play_note =>
                -- update the beat cnt to control the tone length
                if beat_cnt < tone_len_buff * QUATER_BEAT -1 then
                    beat_cnt <= beat_cnt + 1;
                    next_note <= '0'; 
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