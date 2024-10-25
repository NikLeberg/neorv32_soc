-- =============================================================================
-- File:                    arb_round_robin.vhdl
--
-- Entity:                  arb_round_robin
--
-- Description:             Round-robin based arbitration cell.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2023-09-10, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY arb_round_robin IS
    GENERIC (
        NUM : POSITIVE := 3 -- how many requests to arbitrate
    );
    PORT (
        req  : IN STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0); -- requests
        prev : IN STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0); -- to whom was last granted access
        ack  : OUT STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0) -- acknowledge of request
    );
END ENTITY arb_round_robin;

ARCHITECTURE no_target_specific OF arb_round_robin IS
    SIGNAL mask : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0);
    SIGNAL req_masked, req_unmasked : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0);
    SIGNAL ack_masked, ack_unmasked : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0);
    CONSTANT all_zeros : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN

    mask_proc : PROCESS (prev) IS
    BEGIN
        mask <= (OTHERS => '1');
        FOR n IN 0 TO NUM - 1 LOOP
            mask(n) <= '0';
            IF prev(n) = '1' THEN
                EXIT;
            END IF;
        END LOOP;
    END PROCESS mask_proc;

    req_masked <= req AND mask;

    masked_priority_proc : PROCESS (req_masked) IS
    BEGIN
        ack_masked <= (OTHERS => '0');
        FOR n IN 0 TO NUM - 1 LOOP
            IF req_masked(n) = '1' THEN
                ack_masked(n) <= '1';
                EXIT;
            END IF;
        END LOOP;
    END PROCESS masked_priority_proc;

    req_unmasked <= req;

    unmasked_priority_proc : PROCESS (req_unmasked) IS
    BEGIN
        ack_unmasked <= (OTHERS => '0');
        FOR n IN 0 TO NUM - 1 LOOP
            IF req_unmasked(n) = '1' THEN
                ack_unmasked(n) <= '1';
                EXIT;
            END IF;
        END LOOP;
    END PROCESS unmasked_priority_proc;

    ack <= ack_masked WHEN (ack_masked /= all_zeros) ELSE
        ack_unmasked;

END ARCHITECTURE no_target_specific;
