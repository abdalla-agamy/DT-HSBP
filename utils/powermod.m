function r = powermod(base,exp,modulus)

r = 1;

base = mod(base,modulus);

while exp > 0

    if mod(exp,2)==1
        r = mod(r*base,modulus);
    end

    exp = floor(exp/2);

    base = mod(base*base,modulus);

end

end