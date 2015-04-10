/*
 * Copyright (C) 2014-2015 Canonical Ltd
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

package helpers

import (
	"bytes"
	"io"
	"os"
)

const bufsz = 16 * 1024

func FilesAreEqual(a, b string) bool {
	fa, err := os.Open(a)
	if err != nil {
		return false
	}
	defer fa.Close()

	fb, err := os.Open(b)
	if err != nil {
		return false
	}
	defer fb.Close()

	fia, err := fa.Stat()
	if err != nil {
		return false
	}

	fib, err := fb.Stat()
	if err != nil {
		return false
	}

	if fia.Size() != fib.Size() {
		return false
	}

	return streamsEqual(fa, fb)
}

func streamsEqual(fa, fb io.Reader) bool {
	bufa := make([]byte, bufsz)
	bufb := make([]byte, bufsz)
	for {
		ra, erra := io.ReadFull(fa, bufa)
		rb, errb := io.ReadFull(fb, bufb)
		if erra == io.EOF && errb == io.EOF {
			return true
		}
		if (erra != nil || errb != nil) && !(erra == io.ErrUnexpectedEOF && errb == io.ErrUnexpectedEOF && ra == rb) {
			return false
		}
		if !bytes.Equal(bufa[:ra], bufb[:rb]) {
			return false
		}
	}
	panic("can't happen")
}
