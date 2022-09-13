a = rand(4,4);
min_a = min(a(:));
max_a = max(a(:));
norm_a = (a - min_a)/(max_a - min_a);
[m, n] = size(norm_a);
size_block = 16;
mat_color = zeros(m* 16,n*16,3);
for i = 1:1:m
    for j = 1:1:n
        block_t = (i - 1)*size_block +1;
        block_b = i * size_block;
        block_l = (j - 1)* size_block + 1;
        block_r = j * size_block;
        mat_color(block_t:block_b,block_l:block_r,1) = norm_a(i,j);
    end
end
figure;
imshow(mat_color);