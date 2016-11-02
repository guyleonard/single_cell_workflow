#!/bin/bash

THREADS=18
SEQ_DIR="/storage/single_cells/completed"

for dir in *; do
    if [[ -d $dir ]]; then
       echo "${dir}"
       cd $dir

       # remove old fastq files
       echo "Removing .fastq"
       rm *.fastq
       rm *.fq

       # remove other old junk files
       echo "Removing junk files"
       rm "${dir}_mt_mapped_unassembled_paired_reads.qsort.bam"
       rm "${dir}_mt_mapped_all_reads.bam"
       rm "${dir}_mt_mapped_all_reads.bam.bai"

	# samtools index the bam files
	echo "Indexing *.bam files"
	samtools index "${dir}_mt_mapped_assembled_reads.bam"
	samtools index "${dir}_mt_mapped_unassembled_paired_reads.bam"
	samtools index "${dir}_mt_mapped_unassembled_unpaired_forward_reads.bam"
	samtools index "${dir}_mt_mapped_unassembled_unpaired_reverse_reads.bam"

	# get the scaffolds from the fasta file
        # and extract the reads from the bame
	echo "Extract Reads for each Scaffold"
	grep ">" ${dir}_mt.fa | while read -r line ; do

		# by the power of magic pattern substitution!
		scaffold=${line/>/}
		node_array=(${line//_/ })
		node="${node_array[1]}_${node_array[2]}"

		echo "Extracting reads that match to ${node}"
		samtools view -bh ${dir}_mt_mapped_assembled_reads.bam ${scaffold} > ${node}_mapped_assembled_reads.bam
		samtools view -bh ${dir}_mt_mapped_unassembled_paired_reads.bam ${scaffold} > ${node}_mapped_unassembled_paired_reads.bam
		samtools view -bh ${dir}_mt_mapped_unassembled_unpaired_forward_reads.bam ${scaffold} > ${node}_mapped_unassembled_unpaired_forward_reads.bam
		samtools view -bh ${dir}_mt_mapped_unassembled_unpaired_reverse_reads.bam ${scaffold} > ${node}_mapped_unassembled_unpaired_reverse_reads.bam

		echo "Converting extracted bams to fastq"
		bedtools bamtofastq -i ${node}_mapped_assembled_reads.bam -fq ${node}_mapped_assembled_reads.fq
		# bedtools can't handle pairs that are out of order
		#bedtools bamtofastq -i ${node}_mapped_unassembled_paired_reads.bam -fq ${node}_mapped_unassembled_paired_forward_reads.fq -fq2 ${node}_mapped_unassembled_paired_reverse_reads.fq
		bedtools bamtofastq -i ${node}_mapped_unassembled_unpaired_forward_reads.bam -fq ${node}_mapped_unassembled_unpaired_forward_reads.fq
		bedtools bamtofastq -i ${node}_mapped_unassembled_unpaired_reverse_reads.bam -fq ${node}_mapped_unassembled_unpaired_reverse_reads.fq

		echo "Converting paired read bam to interleaved fastq"
		bamtools convert -format fastq -in ${node}_mapped_unassembled_paired_reads.bam > ${node}_mapped_unassembled_paired_unordered_interleaved_reads.fq
	done

	# concatenate all .fq reads to respective libraries
        echo "concat .fq files to .fastq"
	cat *assembled_reads.fq > ${dir}_assembled_reads.fastq
	#cat *unassembled_paired_forward_reads.fq > ${dir}_unassembled_paired_forward_reads.fastq
	#cat *unassembled_paired_reverse_reads.fq > ${dir}_unassembled_paired_reverse_reads.fastq
	cat *unassembled_paired_unordered_interleaved_reads.fq > ${dir}_unassembled_paired_unordered_interleaved_reads.fastq
	cat *unassembled_unpaired_forward_reads.fq > ${dir}_unassembled_unpaired_forward_reads.fastq
	cat *unassembled_unpaired_reverse_reads.fq > ${dir}_unassembled_unpaired_reverse_reads.fastq

        echo "Sorting interleaved fastq"
        cat ${dir}_unassembled_paired_unordered_interleaved_reads.fastq | paste - - - - | sort -k1,1 -S 3G | tr '\t' '\n' > ${dir}_unassembled_paired_interleaved_reads.fastq
        rm ${dir}_unassembled_paired_unordered_interleaved_reads.fastq

	mkdir node_fq
	mv *.fq node_fq

	mkdir node_bam
	mv NODE*.bam node_bam

	cd ../
    fi
done