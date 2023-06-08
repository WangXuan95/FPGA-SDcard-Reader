
//--------------------------------------------------------------------------------------------------------
// Module  : sdcmd_ctrl
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: sdcmd signal control,
//           instantiated by sd_reader
//--------------------------------------------------------------------------------------------------------

module sdcmd_ctrl (
    input  wire         rstn,
    input  wire         clk,
    // SDcard signals (sdclk and sdcmd)
    output reg          sdclk,
    inout               sdcmd,
    // config clk freq
    input  wire  [15:0] clkdiv,
    // user input signal
    input  wire         start,
    input  wire  [15:0] precnt,
    input  wire  [ 5:0] cmd,
    input  wire  [31:0] arg,
    // user output signal
    output reg          busy,
    output reg          done,
    output reg          timeout,
    output reg          syntaxe,
    output wire  [31:0] resparg
);


initial {busy, done, timeout, syntaxe} = 0;
initial sdclk = 1'b0;

localparam [7:0] TIMEOUT = 8'd250;

reg sdcmdoe  = 1'b0;
reg sdcmdout = 1'b1;

// sdcmd tri-state driver
assign sdcmd = sdcmdoe ? sdcmdout : 1'bz;
wire sdcmdin = sdcmdoe ? 1'b1 : sdcmd;

function  [6:0] CalcCrc7;
    input [6:0] crc;
    input [0:0] inbit;
//function automatic logic [6:0] CalcCrc7(input logic [6:0] crc, input logic inbit);
begin
    CalcCrc7 = ( {crc[5:0],crc[6]^inbit} ^ {3'b0,crc[6]^inbit,3'b0} );
end
endfunction

reg  [ 5:0] req_cmd = 6'd0;    // request[45:40]
reg  [31:0] req_arg = 0;       // request[39: 8]
reg  [ 6:0] req_crc = 7'd0;    // request[ 7: 1]
wire [51:0] request = {6'b111101, req_cmd, req_arg, req_crc, 1'b1};

//struct packed {
reg         resp_st;
reg  [ 5:0] resp_cmd;
reg  [31:0] resp_arg;
//} response = 0;

assign resparg = resp_arg;

reg  [17:0] clkdivr = 18'h3FFFF;
reg  [17:0] clkcnt  = 0;
reg  [15:0] cnt1 = 0;
reg  [ 5:0] cnt2 = 6'h3F;
reg  [ 7:0] cnt3 = 0;
reg  [ 7:0] cnt4 = 8'hFF;


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        {busy, done, timeout, syntaxe} <= 0;
        sdclk <= 1'b0;
        {sdcmdoe, sdcmdout} <= 2'b01;
        {req_cmd, req_arg, req_crc} <= 0;
        {resp_st, resp_cmd, resp_arg} <= 0;
        clkdivr <= 18'h3FFFF;
        clkcnt  <= 0;
        cnt1 <= 0;
        cnt2 <= 6'h3F;
        cnt3 <= 0;
        cnt4 <= 8'hFF;
    end else begin
        {done, timeout, syntaxe} <= 0;
        
        clkcnt <= ( clkcnt < {clkdivr[16:0],1'b1} ) ? (clkcnt+18'd1) : 18'd0;
        
        if     (clkcnt == 18'd0)
            clkdivr <= {2'h0, clkdiv} + 18'd1;
        
        if (clkcnt == clkdivr)
            sdclk <= 1'b0;
        else if (clkcnt == {clkdivr[16:0],1'b1} )
            sdclk <= 1'b1;
        
        if(~busy) begin
            if(start) busy <= 1'b1;
            req_cmd <= cmd;
            req_arg <= arg;
            req_crc <= 0;
            cnt1 <= precnt;
            cnt2 <= 6'd51;
            cnt3 <= TIMEOUT;
            cnt4 <= 8'd134;
        end else if(done) begin
            busy <= 1'b0;
        end else if( clkcnt == clkdivr) begin
            {sdcmdoe, sdcmdout} <= 2'b01;
            if     (cnt1 != 16'd0) begin
                cnt1 <= cnt1 - 16'd1;
            end else if(cnt2 != 6'h3F) begin
                cnt2 <= cnt2 - 6'd1;
                {sdcmdoe, sdcmdout} <= {1'b1, request[cnt2]};
                if(cnt2>=8 && cnt2<48) req_crc <= CalcCrc7(req_crc, request[cnt2]);
            end
        end else if( clkcnt == {clkdivr[16:0],1'b1} && cnt1==16'd0 && cnt2==6'h3F ) begin
            if(cnt3 != 8'd0) begin
                cnt3 <= cnt3 - 8'd1;
                if(~sdcmdin)
                    cnt3 <= 8'd0;
                else if(cnt3 == 8'd1)
                    {done, timeout, syntaxe} <= 3'b110;
            end else if(cnt4 != 8'hFF) begin
                cnt4 <= cnt4 - 8'd1;
                if(cnt4 >= 8'd96)
                    {resp_st, resp_cmd, resp_arg} <= {resp_cmd, resp_arg, sdcmdin};
                if(cnt4 == 8'd0) begin
                    {done, timeout} <= 2'b10;
                    syntaxe <= resp_st || ((resp_cmd!=req_cmd) && (resp_cmd!=6'h3F) && (resp_cmd!=6'd0));
                end
            end
        end
    end

endmodule
