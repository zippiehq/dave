//! The builder of machine commitments [MachineCommitmentBuilder] is responsible for building the
//! [MachineCommitment]. It is used by the [Arena] to build the commitments of the tournaments.

use std::{
    borrow::BorrowMut, collections::{hash_map::Entry, HashMap}, rc::Rc
};


use super::{
    constants,
    instance::MachineInstance,
    commitment::{
        MachineCommitment,
        build_small_machine_commitment,
        build_big_machine_commitment,
    },
};

use anyhow::Result;

pub struct MachineCommitmentConfig {
    pub kernel_path: String,
    pub worker_paths: Vec<String>,
}

pub struct CachingMachineCommitmentBuilder {
    kernel: Rc<MachineInstance>,
    workers: Vec<Rc<MachineInstance>>,

    context_switch_cycle: u64,
    current_machine_idx: usize,

    commitments: HashMap<u64, HashMap<u64, MachineCommitment>>,
}

impl CachingMachineCommitmentBuilder {
    pub fn new(commitment_config: &MachineCommitmentConfig) -> Result<Self> {
        let kernel = Rc::new(MachineInstance::new(&commitment_config.kernel_path)?);

        let mut workers = Vec::<Rc<MachineInstance>>::new();
        for path in commitment_config.worker_paths.iter() {
            let worker = Rc::new(MachineInstance::new(path)?);
            workers.push(worker);
        }
        
        Ok(CachingMachineCommitmentBuilder {
            kernel: kernel,
            workers: workers,

            context_switch_cycle: 0,
            current_machine_idx: 0,

            commitments: HashMap::new(),
        })
    }

    pub fn build_commitment(
        &mut self,
        base_cycle: u64,
        level: u64,
        log2_stride: u64,
        log2_stride_count: u64,
    ) -> Result<MachineCommitment> {
        if let Entry::Vacant(e) = self.commitments.entry(level) {
            e.insert(HashMap::new());
        } else if self.commitments[&level].contains_key(&base_cycle) {
            return Ok(self.commitments[&level][&base_cycle].clone());
        }

        let commitment = if log2_stride < constants::LOG2_UARCH_SPAN {
            assert!(log2_stride == 0);
            self.build_small_machine_commitment(base_cycle, log2_stride_count)?
        } else {
            assert!(
                log2_stride + log2_stride_count
                    <= constants::LOG2_EMULATOR_SPAN + constants::LOG2_UARCH_SPAN
            );
            self.build_big_machine_commitment(base_cycle, log2_stride, log2_stride_count)?
        };

        self.commitments
            .entry(level)
            .or_default()
            .insert(base_cycle, commitment.clone());

        Ok(commitment)
    }

    fn build_small_machine_commitment(
        &mut self,
        base_cycle: u64,
        log2_stride_count: u64,
    ) -> Result<MachineCommitment> {
        let mut machine = if self.current_machine_idx == 0 {
            self.kernel
        } else {
            self.workers[self.current_machine_idx - 1]
        };
        build_small_machine_commitment(machine.borrow_mut(), base_cycle, log2_stride_count)
    }

    fn build_big_machine_commitment(
        &mut self,
        base_cycle: u64,
        log2_stride: u64,
        log2_stride_count: u64,
    ) -> Result<MachineCommitment> {
        let mut machine = if self.current_machine_idx == 0 {
            self.kernel
        } else {
            self.workers[self.current_machine_idx - 1]
        };
        
        let commitment = build_big_machine_commitment(machine.borrow_mut(), base_cycle, log2_stride, log2_stride_count);
        self.context_switch_cycle += 1;

        commitment
    }
}
