`timescale 1ns / 1ps
module tb;

    // Testbench Signals
    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [9:0] LEDR;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [35:0] GPIO;
    
    logic txd, rxd, rda, tbr, rda_0, tbr_0;
    logic iocs, iorw, iocs_0, iorw_0;
    logic [1:0] ioaddr, ioaddr_0, br_cfg;
    wire [7:0] databus, databus_0;
    integer i;

    // press button[0] to generate a low active reset signal
    wire rst = KEY[0];

    // Assign switches for baud rate configuration
    assign br_cfg = SW[9:8];

    // Instantiate SPART modules
    spart spart0 (
        .clk(CLOCK_50),
        .rst(rst),
        .iocs(iocs_0),
        .iorw(iorw_0),
        .rda(rda_0),
        .tbr(tbr_0),
        .ioaddr(ioaddr_0),
        .databus(databus_0),
        .txd(rxd_0),
        .rxd(txd)
    );

    spart spart1 (
        .clk(CLOCK_50),
        .rst(rst),
        .iocs(iocs),
        .iorw(iorw),
        .rda(rda),
        .tbr(tbr),
        .ioaddr(ioaddr),
        .databus(databus),
        .txd(txd),
        .rxd(rxd)
    );

    // Instantiate Driver module
    driver driver (
        .clk(CLOCK_50),
        .rst(rst),
        .br_cfg(br_cfg),
        .iocs(iocs),
        .iorw(iorw),
        .rda(rda),
        .tbr(tbr),
        .ioaddr(ioaddr),
        .databus(databus)
    );


    // TB Signals
    logic [9:0] line;
    logic [7:0] data;

    // Testbench Procedure
    initial begin
        CLOCK_50 = 0;
        KEY = 4'b1111; 
        SW = 10'b0000000000;
        rxd = 1;

        // Driver is going to send HELLOWORLD using spart1 to spart0, which is going to be displayed by the TB in ASCII
        $display("Beginning testing with two SPARTs, printf, and one driver");

        // Apply Reset
        @(negedge CLOCK_50) KEY[0] = 0;
        @(negedge CLOCK_50) KEY[0] = 1; 

        // Turn on spart0 to receive from spart1
        iocs_0 = 0;
        ioaddr_0 = 2'b00;
        iorw_0 = 1;

        // Start transmitting data to SPART (act like keyboard)
        @(negedge CLOCK_50) begin 
            SW[9:8] = 2'b00;        // Baud rate configuration
            rxd = 0;
        end

        // Sending ASCII 'H' from spart1 to spart0 (terminal)
        data = 8'b01001000;  // ASCII 'H'

        // Send the data bits to SPART1 (acting like keyboard)
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge spart1.shift)
                rxd = data[i];  // Send each bit of the line to spart0
            $display("Sending bit %d: %b", i+1, data[i]);
        end

        @(posedge spart1.shift)
            rxd = 1; // Stop bit

        // Start transmitting to other buffer
        @(posedge rda) begin // Wait for received data to be available
            $display("Data received by SPART: %b", spart1.receive_buffer);
            $display("Data expected by SPART: %b", data);
            if (spart1.receive_buffer == data) begin
                $display("Data received successfully!");
            end 
            else begin
                $display("Data mismatch! at time %t", $time);
                repeat(3)@(posedge CLOCK_50);
                $stop();
            end
        end

        $display("Sending data from SPART to driver...");
        @(posedge driver.state == 2) begin
            if (driver.databus !== data) begin
                $display("Data received by driver: %b", driver.databus);
                $display("Data expected by driver: %b", data);
                $display("Data mismatch! at time %t", $time);
                repeat (2)@(posedge CLOCK_50);
                $stop();
            end
            else    
                $display("Data received successfully!");
        end

        // Now transmit H to the other SPART
        iocs_0 = 1;                         // enable SPART0


        @(posedge spart0.rda) begin
            $display("Data received by SPART0: %b", spart0.receive_buffer);
            $display("Data expected by SPART: %b", data);
            if (spart0.receive_buffer == data) begin
                $display("Data received successfully!");
            end 
            else begin
                $display("Data mismatch! at time %t", $time);
                repeat(3)@(posedge CLOCK_50);
                $stop();
            end
        end
        $stop();
    end

    always #5 CLOCK_50 = ~CLOCK_50; // Clock
endmodule

