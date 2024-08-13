# CRC-CS-sem2

INTRODUCTION:
🗂️ Linux files may containg holes. For the purpose of this task, we assume that a sparse file consists of contiguous fragments. At the beginning of a fragment, there is a two-byte length indicating the number of bytes of data in the fragment. Next comes the data. The fragment ends with a four-byte offset that specifies how many bytes to skip from the end of this fragment to the beginning of the next fragment. The length of the data in the block is a 16-bit number in natural binary coding. The offset is a 32-bit number in two's complement encoding. The numbers in the file are stored in little-endian order. The first fragment starts at the beginning of the file. The last fragment is identified by its offset pointing to itself. Fragments in the file may touch and overlap.

🗂️ We calculate the file's checksum using a cyclic redundancy check (CRC), taking into account the data in consecutive fragments of the file. We process the file's data byte by byte. We assume that the most significant bit of the data byte and the CRC polynomial (divisor) is written on the left side.

THE PROBLEM:
🗂️ Project is assembly implementation of a program that calculates the checksum of the data contained in the given sparse file:

🗂️ ./crc file crc_poly

🗂️ The file parameter is the name of the file. The crc_poly parameter is a string of zeros and ones describing the CRC polynomial. We do not include the coefficient for the highest power. The maximum degree of the CRC polynomial is 64 (the maximum length of the CRC divisor is 65). We consider a constant polynomial invalid.

🗂️ The program outputs the calculated checksum as a string of zeros and ones, followed by a newline character \n. The program signals successful completion with exit code 0.

🗂️ The program checks the correctness of the parameters and the correctness of the execution of system functions (except for sys_exit). If any parameter is incorrect or if a system function call fails, the program exits with code 1. In every situation, the program explicitly calls sys_close for any file it opened before exiting.
