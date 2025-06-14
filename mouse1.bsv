package mouse1;
//Integer tOTAL_BITS=11;

//Integer tIMER_60USEC_VALUE_PP = 2950; // Number of sys_clks for 60usec.

//Integer tIMER_60USEC_BITS_PP  = 12;   // Number of bits needed for timer

Integer tIMER_5USEC_VALUE_PP = 186;   // Number of sys_clks for debounce

//Integer tIMER_5USEC_BITS_PP  = 8;     // Number of bits needed for 


typedef struct {

  Bool reset;

  Bool ps2_clk_i;

  Bit#(1) ps2_data_i;

  Bool rx_read;

  Bit#(8) tx_data;

  Bool tx_write;

  Bit#(8) divide_reg_i;

} Inputs_struct deriving (Bits, Eq);

typedef struct{

Bit#(1) ps2_clk_en_o;

Bit#(1) ps2_data_en_o;

Bit#(8) rx_scan_code;

Bit#(1) rx_data_ready;

Bool tx_write_ack_o;

Bit#(1) tx_error_no_ack;

}Outputs_struct deriving(Bits,Eq);

typedef enum {

  M1_rx_clk_l,

  M1_rx_clk_h,

  M1_tx_wait_clk_h,

  M1_tx_force_clk_l,

  M1_tx_clk_h,

  M1_tx_clk_l,

  M1_tx_wait_ack,

  M1_tx_done_recovery,

  M1_tx_error_no_ack,

  M1_tx_rising_edge_marker,

  M1_tx_first_wait_clk_h,

  M1_tx_first_wait_clk_l,

  M1_tx_reset_timer,

  M1_rx_falling_edge_marker,

  M1_rx_rising_edge_marker

} M1_State deriving (Bits, Eq);

 

typedef enum {

  M2_rx_data_ready_ack,

  M2_rx_data_ready

} M2_State deriving (Bits, Eq);

interface Ps2_mouse_ifc; 

  method Action set_inputs(Inputs_struct  inputs);

  method Outputs_struct get_outputs();

endinterface


module mkMouse(Ps2_mouse_ifc); //Define methods for inputs and outputs



Reg#(Bool) rx_released <- mkReg(False);

Reg#(Bit#(8)) rx_scan_code <- mkReg(0);

Reg#(Bit#(1)) rx_data_ready <- mkReg(0);

Reg#(Bit#(1)) tx_error_no_ack <- mkReg(0);

// Internal signal declarations

Reg#(Bit#(1)) timer_done <- mkReg(0);

Reg#(Bit#(8)) timer_5usec <- mkReg(1);

Reg#(Bit#(11)) q <- mkReg(0);//total_bits

Reg#(M1_State) m1_state <- mkReg(M1_rx_clk_h);

Reg#(M1_State) m1_next_state <- mkReg(M1_rx_clk_h);

Reg#(M2_State) m2_state <- mkReg(M2_rx_data_ready_ack);

Reg#(M2_State) m2_next_state <- mkReg(M2_rx_data_ready_ack);

Reg#(Bit#(4)) bit_count <- mkReg(0);

Reg#(Bit#(1)) enable_timer_60usec <- mkReg(0);

Reg#(Bit#(1)) enable_timer_5usec <- mkReg(0);

Reg#(Bit#(12)) timer_60usec_count <- mkReg(0);//timer_60usec_bits_pp

Reg#(Bit#(8)) timer_5usec_count <- mkReg(0);//timer_5usec_bits_pp

Reg#(Bool) ps2_clk_s <- mkReg(False);

Reg#(Bit#(1)) ps2_data_s <- mkReg(0);

Reg#(Bit#(1)) ps2_clk_hi_z <- mkReg(1);

Reg#(Bit#(1)) ps2_data_hi_z <- mkReg(1);

Reg#(Bool) ps2_clk_ms <- mkReg(False);

Reg#(Bit#(1)) ps2_data_ms <- mkReg(0);

Reg#(Bool) reset <- mkReg(False);

Reg#(Bool) ps2_clk_i <- mkReg(False);

Reg#(Bit#(1)) ps2_data_i <- mkReg(0);

Reg#(Bit#(8)) tx_data <- mkReg(0);

Reg#(Bool) tx_write <- mkReg(False);

Reg#(Bool) rx_read <- mkReg(False);

Reg#(Bit#(8)) divide_reg_i <- mkReg(0);


let ps2_clk_en_o=ps2_clk_hi_z;

let ps2_data_en_o=ps2_data_hi_z;


rule sample_ps2;

  ps2_clk_ms <=  ps2_clk_i;

  ps2_data_ms <=  ps2_data_i;

  ps2_clk_s <=  ps2_clk_ms;

  ps2_data_s <=  ps2_data_ms;

endrule

// State register

rule m1_state_rule;

  if (reset) m1_state <=  M1_rx_clk_h;

  else m1_state <=  m1_next_state;

endrule

let timer_60usec_done = (timer_60usec_count == 2950) ? 1 : 0;//tIMER_60USEC_VALUE_PP 
let timer_5usec_done = (timer_5usec_count == (divide_reg_i - 1)) ? 1 : 0;
let rx_shifting_done = (bit_count == 11);//total_bits

let tx_shifting_done = (bit_count == 11-1);//total_bits
let rx_output_strobe=rx_shifting_done;


// State transition logic


rule m1_fsm;


    case (m1_state)

        M1_rx_clk_h: begin

            enable_timer_60usec <= 1;

            if (tx_write)

                m1_next_state <= M1_tx_reset_timer;

            else if (!ps2_clk_s)

                m1_next_state <= M1_rx_falling_edge_marker;

            else

                m1_next_state <= M1_rx_clk_h;

        end

 

        M1_rx_falling_edge_marker: begin


            enable_timer_60usec <= 0;

            m1_next_state <= M1_rx_clk_l;

        end

 

        M1_rx_rising_edge_marker: begin


            enable_timer_60usec <= 0;

            m1_next_state <= M1_rx_clk_h;

        end

 

        M1_rx_clk_l: begin


            enable_timer_60usec <= 1;

            if (tx_write)

                m1_next_state <= M1_tx_reset_timer;

            else if (ps2_clk_s)

                m1_next_state <= M1_rx_rising_edge_marker;

            else

                m1_next_state <= M1_rx_clk_l;

        end

 

        M1_tx_reset_timer: begin


            enable_timer_60usec <= 0;

            m1_next_state <= M1_tx_force_clk_l;

        end

 

        M1_tx_force_clk_l: begin


            enable_timer_60usec <= 1;

            ps2_clk_hi_z <= 0;  // Force ps2_clk low

            if (unpack(timer_60usec_done))

                m1_next_state <= M1_tx_first_wait_clk_h;

            else

                m1_next_state <= M1_tx_force_clk_l;

        end

 

        M1_tx_first_wait_clk_h: begin


            enable_timer_5usec <= 1;

            ps2_data_hi_z <= 0; // Start bit

            if (!ps2_clk_s && unpack(timer_5usec_done))

                m1_next_state <= M1_tx_clk_l;

            else

                m1_next_state <= M1_tx_first_wait_clk_h;

        end

 

        M1_tx_first_wait_clk_l: begin


            ps2_data_hi_z <= 0;

            if (!ps2_clk_s)

                m1_next_state <= M1_tx_clk_l;

            else

                m1_next_state <= M1_tx_first_wait_clk_l;

        end

 

        M1_tx_wait_clk_h: begin


            enable_timer_5usec <= 1;

            ps2_data_hi_z <= q[0];

            if (ps2_clk_s && unpack(timer_5usec_done))

                m1_next_state <= M1_tx_rising_edge_marker;

            else

                m1_next_state <= M1_tx_wait_clk_h;

        end

 

        M1_tx_rising_edge_marker: begin


            ps2_data_hi_z <= q[0];

            m1_next_state <= M1_tx_clk_h;

        end

 

        M1_tx_clk_h: begin


            ps2_data_hi_z <= q[0];

            if (tx_shifting_done)

                m1_next_state <= M1_tx_wait_ack;

            else if (!ps2_clk_s)

                m1_next_state <= M1_tx_clk_l;

            else

                m1_next_state <= M1_tx_clk_h;

        end

 

        M1_tx_clk_l: begin


            ps2_data_hi_z <= q[0];

            if (ps2_clk_s)

                m1_next_state <= M1_tx_wait_clk_h;

            else

                m1_next_state <= M1_tx_clk_l;

        end

 

        M1_tx_wait_ack: begin


            if (!ps2_clk_s && unpack(ps2_data_s))

                m1_next_state <= M1_tx_error_no_ack;

            else if (!ps2_clk_s && !unpack(ps2_data_s))

                m1_next_state <= M1_tx_done_recovery;

            else

                m1_next_state <= M1_tx_wait_ack;

        end

 

        M1_tx_done_recovery: begin


            if (ps2_clk_s && unpack(ps2_data_s))

                m1_next_state <= M1_rx_clk_h;

            else

                m1_next_state <= M1_tx_done_recovery;

        end

 

        M1_tx_error_no_ack: begin


            tx_error_no_ack <= 1;

            if (ps2_clk_s && unpack(ps2_data_s))

                m1_next_state <= M1_rx_clk_h;

            else

                m1_next_state <= M1_tx_error_no_ack;

        end

 

        default: begin


            m1_next_state <= M1_rx_clk_h;

        end

 

    endcase

endrule

//Rule for default : m1_next_state <=  M1_rx_clk_h;

// State register

rule m2;

  if (reset) m2_state <=  M2_rx_data_ready_ack;

  else m2_state <=  m2_next_state;

endrule

 

// State transition logic

rule m2_fsm;

    case (m2_state)

 

        M2_rx_data_ready_ack: begin

            rx_data_ready <= 0;

            if (rx_output_strobe)

                m2_next_state <= M2_rx_data_ready;

            else

                m2_next_state <= M2_rx_data_ready_ack;

        end

 

        M2_rx_data_ready: begin

            rx_data_ready <= 1;

            if (rx_read)

                m2_next_state <= M2_rx_data_ready_ack;

            else

                m2_next_state <= M2_rx_data_ready;

        end

 

        default: begin

            m2_next_state <= M2_rx_data_ready_ack;

        end

 

    endcase

endrule// This is the bit counter

rule bit_counter;

  if (   reset

      || rx_shifting_done

      || (m1_state == M1_tx_wait_ack)        // After tx is done.

      ) bit_count <=  0;  // normal reset

  else if (unpack(timer_60usec_done)

           && (m1_state == M1_rx_clk_h)

           && (ps2_clk_s)

      ) bit_count <=  0;  // rx watchdog timer reset

  else if ( (m1_state == M1_rx_falling_edge_marker)   // increment for rx

           ||(m1_state == M1_tx_rising_edge_marker)   // increment for tx

           )

    bit_count <=  bit_count + 1;

endrule

// This signal is high for one clock at the end of the timer count.



// This is the signal which enables loading of the shift register.

// It also indicates "ack" to the device writing to the transmitter.

let tx_write_ack_o = (  (tx_write && (m1_state == M1_rx_clk_h))

                         ||(tx_write && (m1_state == M1_rx_clk_l))

                         );

 

// This is the ODD parity bit for the transmitted word.

let tx_parity_bit = ~^tx_data;

 

// This is the shift register

rule shift_reg;

  if (reset) q <=  0;

  else if (tx_write_ack_o) q <=  {1'b1,tx_parity_bit,tx_data,1'b0};

  else if ( (m1_state == M1_rx_falling_edge_marker)

           ||(m1_state == M1_tx_rising_edge_marker) )

    q <=  {ps2_data_s,q[10-1:1]};//total_bits

endrule

// This is the 60usec timer counter

rule timer_counter_60usec;

  if (!unpack(enable_timer_60usec)) timer_60usec_count <=  0;

  else if ( unpack(timer_done) && !unpack(timer_60usec_done))

         timer_60usec_count<=  timer_60usec_count +1;

 endrule



rule rl_timer_5usec;

if (reset) timer_5usec <=  1;

else if (!unpack(enable_timer_60usec)) timer_5usec <=  1;

else if (timer_5usec == divide_reg_i)

 begin

   timer_5usec <=  1;

   timer_done  <=  1;

  end

else

  begin

    timer_5usec<=  timer_5usec +1;

    timer_done  <=  0;

 end

endrule

rule timer_counter_5usec;

  if (!unpack(enable_timer_5usec)) timer_5usec_count <=  0;

  else if (!unpack(timer_5usec_done)) timer_5usec_count <=  timer_5usec_count + 1;

endrule


rule rx_scan_code_rl;

  if (reset) rx_scan_code <=  0;

  else if (rx_output_strobe) rx_scan_code <=  q[8:1];

endrule



method Action set_inputs(Inputs_struct inputs);

  reset<=inputs.reset;

  ps2_clk_i<=inputs.ps2_clk_i;

 ps2_data_i<=inputs.ps2_data_i;

  rx_read<=inputs.rx_read;

  tx_data<=inputs.tx_data;

  tx_write<=inputs.tx_write;

  divide_reg_i<=inputs.divide_reg_i;

endmethod

method Outputs_struct get_outputs;

return Outputs_struct{

    rx_scan_code: rx_scan_code, 

    rx_data_ready: rx_data_ready,

    ps2_clk_en_o: ps2_clk_hi_z,

    ps2_data_en_o: ps2_data_hi_z,

    tx_write_ack_o: tx_write_ack_o,

    tx_error_no_ack: tx_error_no_ack

};

endmethod

endmodule
endpackage	

