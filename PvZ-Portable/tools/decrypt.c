/*
 * Copyright (C) 2026 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * SPDX-License-Identifier: LGPL-3.0-or-later
 *
 * This file is part of PvZ-Portable.
 *
 * PvZ-Portable is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PvZ-Portable is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with PvZ-Portable. If not, see <https://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>

int main() {
	FILE *fp = fopen("main.pak", "rb");

	fseek(fp, 0, SEEK_END);
	size_t size = ftell(fp);
	rewind(fp);

	char *ptr = malloc(size);
	fread(ptr, 1, size, fp);
	fclose(fp);

	for (int i = 0; i < size; i++)
		ptr[i] = (ptr[i]) ^ 0xF7; // 'Decrypt'

	FILE *wp = fopen("main.unpak", "wb");
	fwrite(ptr, 1, size, wp);
	fclose(wp);
	free(ptr);
	return 0;
}
