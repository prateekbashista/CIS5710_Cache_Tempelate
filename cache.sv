`timescale 1ns/1ps

/*--------------------------------------------------------------------------
    Specifications of the Cache :
    - 2 Way Set Associativity
    - Block Size of 4 Bytes
    - Pipelined Implementation
    - Requests aligned to 4B Boundaries
    - Writeback Policy
    - Read Allocate/ Write Allocate Policy
--------------------------------------------------------------------------*/

module cache
(
/*--------------------------------------------------------------------------
    system clock and reset
--------------------------------------------------------------------------*/
input                       clk,                // System Clock
input                       rst_n,              // Negative Edge Triggered Sychronous Reset

/*---------------------------------------------------------------------------
    AXI Lite Subordinate Mode - From Processor
---------------------------------------------------------------------------*/

input [31:0]                axil_awaddr_sbd,    // Write Address In
input                       axil_awvalid_sbd,   // Write Address valid In
output logic                axil_awready_sbd,   // Write Address Ready Out

input [31:0]                axil_wdata_sbd,     // Write Data Value In
input                       axil_wvalid_sbd,    // Write Data Valid In
output logic                axil_wready_sbd,    // Write Data Ready Out

output logic [1:0]          axil_bresp_sbd,     // Write Response Out
output logic                axil_bvalid_sbd,    // Write Response Valid Out
input                       axil_bready_sbd,    // Write Response Ready In

input [31:0]                axil_araddr_sbd,    // Read Address In
input                       axil_arvalid_sbd,   // Read Address Valid In
output logic                axil_arready_sbd,   // Read Address Ready Out

output logic [31:0]         axil_rdata_sbd,     // Read Data Out
output logic                axil_rvalid_sbd,    // Read Data Valid Out
output logic [1:0]          axil_rresp_sbd,     // Read Response Status Out 
input                       axil_rready_sbd,    // Read Response Ready In

/*---------------------------------------------------------------------------
    AXI Lite Manager Mode - To next level of memory
---------------------------------------------------------------------------*/

output logic [31:0]         axil_awaddr_mng,    // Write Address Out
output logic                axil_awvalid_mng,   // Write Address Valid Out
input                       axil_awready_mng,   // Write Address Ready In

output logic [31:0]         axil_wdata_mng,     // Write Data Out
output logic                axil_wvalid_mng,    // Write Data Valid Out
input                       axil_wready_mng,    // Write Data In

input [1:0]                 axil_bresp_mng,     // Write Response In
input                       axil_bvalid_mng,    // Write Response Valid In
output logic                axil_bready_mng,    // Write Response Ready Out

output logic [31:0]         axil_araddr_mng,    // Read Address Out
output logic                axil_arvalid_mng,   // Read Address Valid Out
input                       axil_arready_mng,   // Read Address Ready In

input [31:0]                axil_rdata_mng,     // Read Data In
input [1:0]                 axil_rresp_mng,     // Read Response In
input                       axil_rvalid_mng,    // Read Response Valid In
output logic                axil_rready_mng     // Read Response Ready Out
);


    typedef enum logic [3:0] {  IDLE  = 4'h0,
                                WAIT_FOR_DATA = 4'h1,
                                READ = 4'h2,
                                WRITE = 4'h3,
                                MEM_READ_REQ = 4'h4,
                                MEM_AXI_RRESP = 4'h5,
                                MEM_WRITE_REQ = 4'h6,
                                MEM_AXI_BRESP = 4'h7,
                                READ_UPDATE = 4'h8,
                                WRITE_UPDATE = 4'h9,
                                MNG_RREADY = 4'hA,
                                MNG_BREADY = 4'hB } states;

    states state, next_state;

    /*--------------------------------------------------------------------------
        Calculation of the Tag, Index and Offset Bits
    --------------------------------------------------------------------------*/
    parameter integer BYTE_WIDTH = 8;
    parameter integer SIZE = 32768; // In Bytes -> 32 Kb Cache
    parameter integer BLOCK_SIZE = 1;
    parameter integer WAYS = 2;


    parameter integer CACHE_LINES = $clog2((SIZE*BYTE_WIDTH)/(BLOCK_SIZE*32));
    parameter integer OFFSET = $clog2(BLOCK_SIZE * 32 / BYTE_WIDTH);
    parameter integer INDEX  = CACHE_LINES - $clog2(WAYS);
    parameter integer TAG_SIZE  = 32 - INDEX - OFFSET;
    //---------------------------------------------------------------------------


    
    /*------------------------------------------------------------------------------ 
       We Bank the Cache Across Associativity of a set so that we get parallel access
       to all the cache lines of a set. 
       So for a 2-way set associative cache, 2 banks are required :

                              SET N
            -----------------       -----------------
            |               |       |               |
            -----------------       -----------------
            |               |  <-   |               |   <- Index (Address for RAMs)
            -----------------       -----------------
            |               |       |               |
            -----------------       -----------------
                    '                       '       
                    '                       '
                    '                       '           
                    '                       '   
                    '                       '
            -----------------       -----------------
            |               |       |               |
            -----------------       -----------------    
                   WAY 0                  WAY 1                    
    -------------------------------------------------------------------------------*/



    //------------------------------- Data RAM ----------------------------------
    // For 2 Way Set Associative Cache, 2 Data Banks are Required
    // Size = 2 ^ Index = 2 ^ 12 = 4096 Lines each containing 1 32-Bit Word
    // Size for 1 ram = 4096 x 32/8 = 16384 Bytes

    logic [INDEX - 1 : 0] data_addr;    // Data Read/Write Address
    logic read_enable[2];               // Array, for each Bank Read Enable
    logic [31 : 0] data_out[2];         // Output from the RAM
    logic [31 : 0] data_in[2];          // Data to be written in RAM
    logic write_enable[2];              // Write-Enable

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(INDEX)
    )
    data_ram_0
    (
        .clk(clk),              
        .addr(data_addr),       
        .re(read_enable[0]),                  
        .data_out(data_out[0]),            
        .data_in(data_in[0]),             
        .we(write_enable[0])                   
    );

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(INDEX)
    )
    data_ram_1
    (
        .clk(clk),        
        .addr(data_addr),       
        .re(read_enable[1]),         
        .data_out(data_out[1]),   
        .data_in(data_in[1]),    
        .we(write_enable[1])          
    );
    //---------------------------------------------------------------------------

    //--------------------------Meta-data Tag RAM -------------------------------
    // Since Tag is associated with each cache line, we will require 2 Tag Data Banks
    // Tag Size for current configuration is 18 Address Bits
    // Size = 2 ^ 12 = 4096 Lines each containing 1 18-Bit Tag Data
    // Size for 1 Ram = 4096 x 18 = 73,728 Bits
    // Tag Overhead  = 18 / 32 * 100 = 56.25 %

    logic [INDEX - 1 : 0] tag_addr;    
    logic tag_read_enable[2];               
    logic [TAG_SIZE - 1 : 0] tag_out[2];        
    logic [TAG_SIZE - 1 : 0] tag_in[2];          
    logic tag_write_enable[2];              

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(TAG_SIZE),
        .ADDR_WIDTH(INDEX)
    )
    tag_ram_0
    (
        .clk(clk),              
        .addr(tag_addr),       
        .re(tag_read_enable[0]),                  
        .data_out(tag_out[0]),            
        .data_in(tag_in[0]),             
        .we(tag_write_enable[0])                   
    );

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(TAG_SIZE),
        .ADDR_WIDTH(INDEX)
    )
    tag_ram_1
    (
        .clk(clk),              
        .addr(tag_addr),       
        .re(tag_read_enable[1]),                  
        .data_out(tag_out[1]),            
        .data_in(tag_in[1]),             
        .we(tag_write_enable[1])            
    );
    //---------------------------------------------------------------------------

    //--------------------------Meta-data Valid RAM -----------------------------
    // Since Valid Bit is associated with each cache line, we will require 2 Valid Banks
    // Size = 2 ^ 12 = 4096 Lines each containing 1 1-Bit Valid Data
    // Size for 1 Ram = 4096 x 1 = 4096 Bits

    logic [INDEX - 1 : 0] valid_addr;    
    logic valid_read_enable[2];               
    logic valid_out[2];         
    logic valid_in[2];          
    logic valid_write_enable[2];            

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(1),
        .ADDR_WIDTH(INDEX)
    )
    valid_ram_0
    (
        .clk(clk),              
        .addr(valid_addr),       
        .re(valid_read_enable[0]),                  
        .data_out(valid_out[0]),            
        .data_in(valid_in[0]),             
        .we(valid_write_enable[0])                   
    );

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(1),
        .ADDR_WIDTH(INDEX)
    )
    valid_ram_1
    (
        .clk(clk),              
        .addr(valid_addr),       
        .re(valid_read_enable[1]),                  
        .data_out(valid_out[1]),            
        .data_in(valid_in[1]),             
        .we(valid_write_enable[1])               
    );
    //---------------------------------------------------------------------------

    //--------------------------Meta-data Valid RAM -----------------------------
    // This Cache has Least Recently Used (LRU) eviction policy
    // For associativity > 2, LRU ranking bits are required for all cache lines
    // But, since associativity = 2, we only require 1 bit per set.
    // if lru  = 0, evict way 0, if 1, evict way 1
    // Thus, we only require 1 RAM Bank

    logic [INDEX - 1 : 0] lru_addr;    
    logic lru_read_enable;               
    logic lru_out;         
    logic lru_in;          
    logic lru_write_enable;            

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(1),
        .ADDR_WIDTH(INDEX)
    )
    lru_ram
    (
        .clk(clk),              
        .addr(lru_addr),       
        .re(lru_read_enable),                  
        .data_out(lru_out),            
        .data_in(lru_in),             
        .we(lru_write_enable)                   
    );

    //---------------------------------------------------------------------------    

    //--------------------------Meta-data Dirty RAM -----------------------------
    // Since Dirty Bit is associated with each cache line, we will require 2 Dirty Bit Banks
    // Size = 2 ^ 12 = 4096 Lines each containing 1 1-Bit Dirty Bit Data
    // Size for 1 Ram = 4096 x 1 = 4096 Bits

    logic [INDEX - 1 : 0] dirty_addr;    
    logic dirty_read_enable[2];               
    logic dirty_out[2];         
    logic dirty_in[2];          
    logic dirty_write_enable[2];            

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(1),
        .ADDR_WIDTH(INDEX)
    )
    dirty_ram_0
    (
        .clk(clk),              
        .addr(dirty_addr),       
        .re(dirty_read_enable[0]),                  
        .data_out(dirty_out[0]),            
        .data_in(dirty_in[0]),             
        .we(dirty_write_enable[0])                   
    );

    sram
    #(
        .SIZE(4096),
        .DATA_WIDTH(1),
        .ADDR_WIDTH(INDEX)
    )
    valid_ram_1
    (
        .clk(clk),              
        .addr(dirty_addr),       
        .re(dirty_read_enable[1]),                  
        .data_out(dirty_out[1]),            
        .data_in(dirty_in[1]),             
        .we(dirty_write_enable[1])                  
    );
    //---------------------------------------------------------------------------


    // AXI-Lite State Machine
    always_comb begin : axi_interface
        case(state)
        IDLE : begin

            if(axil_arready_sbd && axil_arvalid_sbd) begin // read address valid
                next_state = READ;
            end
            else if(axil_awready_sbd && axil_awvalid_sbd && axil_wready_sbd && axil_wvalid_sbd) begin
                next_state = WRITE;
            end
            else if(axil_awready_sbd && axil_awvalid_sbd) begin
                next_state = WAIT_FOR_DATA;
            end
            else begin
                next_state = IDLE;
            end
        end
        WAIT_FOR_DATA : begin

            if(axil_wready_sbd && axil_wvalid_sbd) begin
                next_state = WRITE;
            end
            else begin
                next_state = WAIT_FOR_DATA;
            end
        end
        READ : begin
            if(valid_out[0] && tag == tag_out[0]) begin // Hit on Way 0
                
                if(axil_rready_sbd && axil_rvalid_sbd) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = READ;
                end
            end
            else if(valid_out[1] && tag == tag_out[1]) begin // Hit on Way 1
                
                if(axil_rready_sbd && axil_rvalid_sbd) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = READ;
                end
            end
            else begin // Miss

                if(dirty_out[lru_out]) begin // Check if the lru way dirty or clean
                    next_state = MEM_WRITE_REQ;
                end
                else begin
                    next_state = MEM_READ_REQ;
                end
            end
        end
        WRITE : begin
            if(valid_out[0] && tag == tag_out[0]) begin // Hit on Way 0
                
                if(axil_bready_sbd && axil_bvalid_sbd) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = WRITE;
                end
            end
            else if(valid_out[1] && tag == tag_out[1]) begin // Hit on Way 1
                
                if(axil_bready_sbd && axil_bvalid_sbd) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = WRITE;
                end
            end
            else begin // Miss
                
                if(dirty_out[lru_out]) begin // Check if the lru way dirty or clean
                    next_state = MEM_WRITE_REQ;
                end
                else begin
                    next_state = MEM_READ_REQ;
                end
            end
        end
        MEM_READ_REQ : begin
        end
        MEM_AXI_RRESP : begin
        end
        MEM_WRITE_REQ : begin
        end
        MEM_AXI_BRESP : begin
        end
        READ_UPDATE : begin
        end
        WRITE_UPDATE : begin
        end
        MNG_RREADY : begin
        end
        MNG_BREADY : begin
        end
        endcase
    end

    //Address and Data Register
    reg [31:0] read_address;
    logic [31:0] next_read_address;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            read_address <=  0;
        end
        else begin
            read_address <= next_read_address;
        end
    end


    reg [31:0] write_address;
    logic [31:0] next_write_address;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            write_address <= 0;
        end
        else begin
            write_address <= next_write_address;
        end
    end

    reg [31:0] write_data;
    logic [31:0] next_write_data;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            write_data <= 0;
        end
        else begin
            write_data <= next_write_data;
        end
    end


    // Tag and Index Storage Registers
    reg [TAG_SIZE - 1 : 0] tag;
    logic [TAG_SIZE - 1 : 0] next_tag;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            tag <= 0;
        end
        else begin
            tag <= next_tag;
        end
    end

    reg [INDEX - 1 : 0] index;
    logic [INDEX - 1 : 0] next_index;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            index <= 0;
        end
        else begin
            index <= next_index;
        end
    end

    // LRU Location of Way
    reg lru_way;
    logic next_lru_way;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            lru_way <= 0;
        end
        else begin
            lru_way <= next_lru_way;
        end
    end



    // State Datapath
    always_comb begin : state_datapath

        // Defaut State of the Signal
        
        // Subordinate Interface Ready Signals
        axil_arready_sbd = 1'b1;
        axil_awready_sbd = 1'b1;
        axil_wready_sbd = 1'b1;

        // Subordinate B Channel
        axil_bresp_sbd = 2'b0;
        axil_bvalid_sbd = 1'b0;

        // Subordinate R Channel
        axil_rdata_sbd = 32'b0;
        axil_rvalid_sbd = 1'b0;
        axil_rresp_sbd = 2'b0;

        // Manager Interface Signals
        axil_awaddr_mng = 32'b0;   
        axil_awvalid_mng = 1'b0;
        axil_wdata_mng = 32'b0;
        axil_wvalid_mng = 1'b0;
        axil_araddr_mng = 32'b0;  
        axil_arvalid_mng = 1'b0;   

        // Manager B Channel
        axil_bready_mng = 1'b0;
        axil_rready_mng = 1'b0;

        // Default Save value of the Registers
        next_read_address = read_address;
        next_write_address = write_address;
        next_write_data = write_data;
        next_index = index;
        next_tag = tag;
        next_lru_way = lru_way;

        case(state)
        IDLE : begin

            // Subordinate Interface Ready Signals
            axil_arready_sbd = 1'b1;
            axil_awready_sbd = 1'b1;
            axil_wready_sbd = 1'b1;

            // Registering Address
            next_read_address = 0;
            next_write_address = 0;
            next_write_data = 0;

            // Tag and Index
            next_tag = 0;
            next_index = 0;

            if(axil_arready_sbd && axil_arvalid_sbd) begin // read address valid
                
                // Registering Address
                next_read_address = axil_araddr_sbd;
                next_write_address = 0;
                next_write_data = 0;

                // Tag and Index
                next_tag = axil_araddr_sbd[31 : INDEX + OFFSET];
                next_index = axil_araddr_sbd[INDEX + OFFSET - 1 : OFFSET];

                // Reading DATA RAM
                data_addr = axil_araddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                read_enable = 2'b11;

                // Reading Tag RAM
                tag_addr = axil_araddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                tag_read_enable = 2'b11;

                // Reading Valid RAM
                valid_addr = axil_araddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                valid_read_enable = 2'b11;

                // Reading LRU RAM
                lru_addr = axil_araddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                lru_read_enable = 1'b1;

                // Reading the Dirty Bit RAM
                dirty_addr = axil_araddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                dirty_read_enable = 2'b11;

            end
            else if(axil_awready_sbd && axil_awvalid_sbd && axil_wready_sbd && axil_wvalid_sbd) begin
                
                // Registering Address
                next_read_address = 0;
                next_write_address = axil_awaddr_sbd;
                next_write_data = axil_wdata_sbd;

                // Tag and Index
                next_tag = axil_awaddr_sbd[31 : INDEX + OFFSET];
                next_index = axil_awaddr_sbd[INDEX + OFFSET - 1 : OFFSET];

                // Reading DATA RAM
                data_addr = axil_awaddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                read_enable = 2'b11;

                // Reading Tag RAM
                tag_addr = axil_awaddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                tag_read_enable = 2'b11;


                // Reading Valid RAM
                valid_addr = axil_awaddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                valid_read_enable = 2'b11;

                // Reading LRU RAM
                lru_addr = axil_awaddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                lru_read_enable = 1'b1;

                // Reading the Dirty Bit RAM
                dirty_addr = axil_awaddr_sbd[INDEX + OFFSET - 1 : OFFSET];
                dirty_read_enable = 2'b11;
                
            end
            else if(axil_awready_sbd && axil_awvalid_sbd) begin
                
                // Registering Address
                next_read_address = 0;
                next_write_address = axil_awaddr_sbd;
                next_write_data = 0;

                // Tag and Index
                next_tag = axil_awaddr_sbd[31 : INDEX + OFFSET];
                next_index = axil_awaddr_sbd[INDEX + OFFSET - 1 : OFFSET];

            end
        end
        WAIT_FOR_DATA : begin
            // Subordinate Interface Ready Signals
            axil_arready_sbd = 1'b0;
            axil_awready_sbd = 1'b0;
            axil_wready_sbd = 1'b1;

            // Registering Data
            next_write_data = axil_wdata_sbd;

            // Reading DATA RAM
            data_addr = write_address[INDEX + OFFSET - 1 : OFFSET];
            read_enable = 2'b11;

            // Reading Tag RAM
            tag_addr = write_address[INDEX + OFFSET - 1 : OFFSET];
            tag_read_enable = 2'b11;

            // Reading Valid RAM
            valid_addr = write_address[INDEX + OFFSET - 1 : OFFSET];
            valid_read_enable = 2'b11;

            // Reading LRU RAM
            lru_addr = write_address[INDEX + OFFSET - 1 : OFFSET];
            lru_read_enable = 1'b1;

            // Reading the Dirty Bit RAM
            dirty_addr = write_address[INDEX + OFFSET - 1 : OFFSET];
            dirty_read_enable = 2'b11;

        end
        READ : begin

            // Subordinate Interface Ready Signals
            axil_arready_sbd = 1'b0;
            axil_awready_sbd = 1'b0;
            axil_wready_sbd = 1'b0;

            // Re-Read the Valid, TAG and Data Banks Incase of Interface Not Ready
            valid_addr = read_address[index]; valid_read_enable = 2'b11;
            tag_addr = read_address[index]; tag_read_enable = 2'b11;
            data_addr = read_address[index]; read_enable = 2'b11;
            
            if(valid_out[0] && tag == tag_out[0]) begin // Hit on Way 0
                
                // Set LRU
                lru_addr = index;
                lru_in = 1'b1;
                lru_write_enable = 1'b1;

                // Output Data
                axil_rdata_sbd = data_out[0];
                axil_rvalid_sbd = 1'b1;
                axil_rresp_sbd = 2'b00;

            end
            else if(valid_out[1] && tag == tag_out[1]) begin // Hit on Way 1

                // Set LRU
                lru_addr = index;
                lru_in = 1'b0;
                lru_write_enable = 1'b1;

                // Output Data
                axil_rdata_sbd = data_out[1];
                axil_rvalid_sbd = 1'b1;
                axil_rresp_sbd = 2'b00;

            end
            else begin // Miss
                next_lru_way = lru_out;
            end
        end
        WRITE : begin

            // Subordinate Interface Ready Signals
            axil_arready_sbd = 1'b0;
            axil_awready_sbd = 1'b0;
            axil_wready_sbd = 1'b0;

            // Re-Read the Valid, TAG and Data Banks Incase of Interface Not Ready
            valid_addr = write_address[index]; valid_read_enable = 1'b1;
            tag_addr = write_address[index]; tag_read_enable = 1'b1;
            
            
            if(valid_out[0] && tag == tag_out[0]) begin // Hit on Way 0
                
                // Set LRU
                lru_addr = index;
                lru_in = 1'b1;
                lru_write_enable = 1'b1;

                //Write Data
                data_addr = write_address[index]; 
                write_enable[0] = 1'b1;
                data_in[0] = write_data;

                // Output Data
                axil_bvalid_sbd = 1'b1;
                axil_bresp_sbd = 2'b00;

            end
            else if(valid_out[1] && tag == tag_out[1]) begin // Hit on Way 1

                // Set LRU
                lru_addr = index;
                lru_in = 1'b0;
                lru_write_enable = 1'b1;

                //Write Data
                data_addr = write_address[index]; 
                write_enable[1] = 1'b1;
                data_in[1] = write_data;

                // Output Data
                axil_bvalid_sbd = 1'b1;
                axil_bresp_sbd = 2'b00;

            end
            else begin // Miss
                next_lru_way = lru_out;
            end
        end
        MEM_READ_REQ : begin
        end
        MEM_AXI_RRESP : begin
        end
        MEM_WRITE_REQ : begin
        end
        MEM_AXI_BRESP : begin
        end
        READ_UPDATE : begin
        end
        WRITE_UPDATE : begin
        end
        MNG_RREADY : begin
        end
        MNG_BREADY : begin
        end
        endcase
    end

endmodule