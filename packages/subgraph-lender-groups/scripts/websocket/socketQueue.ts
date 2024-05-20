const QUEUE_JOBS_PER_RUN = 3;
const QUEUE_RUN_DELAY = 1000;

interface UpdateQueue {
  id: string;
  action?: string;
  updateFunc: () => void;
}

const updateQueue: UpdateQueue[] = [];
let timeOut: ReturnType<typeof setTimeout>;

export function pushUpdate(update: UpdateQueue): void {
  const shouldRun = updateQueue.length === 0;
  let didUpdate = false;
  for (const u of updateQueue) {
    if (u.id === update.id && u.action === update.action) {
      u.updateFunc = update.updateFunc;
      didUpdate = true;
      break;
    }
  }
  if (!didUpdate) {
    updateQueue.push(update);
  }
  if (shouldRun) {
    startQueue();
  }
}

export function removeIdFromQueue(id: string): void {
  for (let i = 0; i < updateQueue.length; i++) {
    const update = updateQueue[i];
    if (id === update.id) {
      updateQueue.splice(i, 1);
      break;
    }
  }
  if (updateQueue.length === 0) {
    clearTimeout(timeOut);
  }
}

function startQueue(): void {
  const numJobs =
    QUEUE_JOBS_PER_RUN < updateQueue.length
      ? QUEUE_JOBS_PER_RUN
      : updateQueue.length;
  for (let i = 0; i < numJobs; i++) {
    if (updateQueue.length > 0) {
      const u = updateQueue.shift();
      u?.updateFunc();
    }
  }
  if (updateQueue.length > 0) {
    timeOut = setTimeout(() => {
      startQueue();
    }, QUEUE_RUN_DELAY);
  }
}
